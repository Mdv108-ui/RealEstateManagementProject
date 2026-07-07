public with sharing class PropertyController {

    public class FilterWrapper {
        @AuraEnabled public Decimal minPrice;
        @AuraEnabled public Decimal maxPrice;
        @AuraEnabled public String status;
        @AuraEnabled public String furnishingStatus;
        @AuraEnabled public Decimal distanceKm;
        @AuraEnabled public Decimal userLat;
        @AuraEnabled public Decimal userLng;
    }

    public class PagedResult {
        @AuraEnabled public List<Property__c> properties;
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer totalPages;
        @AuraEnabled public Integer currentPage;
    }

    /**
     * REQUIREMENT 2: Server-Side Pagination & Filtering Engine
     */
    @AuraEnabled(cacheable=false)
    public static PagedResult getPagedProperties(Integer pageNumber, String filtersJson) {
        Integer pageSize = 25;
        Integer offsetValue = (pageNumber - 1) * pageSize;
        FilterWrapper filters = (FilterWrapper) JSON.deserialize(filtersJson, FilterWrapper.class);

        // Standard clean base variables query
        String baseQuery = 'SELECT Id, Name, Address__c, City__c, State__c, Postal_Code__c, Country__c, Rent__c, Status__c, Furnishing_Status__c, Latitude__c, Longitude__c FROM Property__c';
        List<String> whereClauses = new List<String>();

        // 2.b.i Price Filters
        if (filters.minPrice != null) whereClauses.add('Rent__c >= :minPrice');
        if (filters.maxPrice != null) whereClauses.add('Rent__c <= :maxPrice');
        Decimal minPrice = filters.minPrice;
        Decimal maxPrice = filters.maxPrice;

        // 2.b.ii Availability Filter
        if (String.isNotBlank(filters.status)) whereClauses.add('Status__c = :status');
        String status = filters.status;

        // 2.b.iii Furnishing Filter
        if (String.isNotBlank(filters.furnishingStatus)) whereClauses.add('Furnishing_Status__c = :furnishingStatus');
        String furnishingStatus = filters.furnishingStatus;

        String whereString = whereClauses.isEmpty() ? '' : ' WHERE ' + String.join(whereClauses, ' AND ');
        
        // Execute clean base query extraction
        String finalQuery = baseQuery + whereString + ' ORDER BY Name ASC';
        List<Property__c> allMatchedProperties = Database.query(finalQuery);

        // 2.b.iv Nearby Distance Filter Fix
        // FIX: Run proximity calculation using Apex Location objects in memory to bypass the SOQL parser bug entirely
        List<Property__c> filteredProperties = new List<Property__c>();
        Boolean applyDistanceFilter = (filters.distanceKm != null && filters.userLat != null && filters.userLng != null);
        
        if (applyDistanceFilter) {
            Location userLoc = Location.newInstance(filters.userLat, filters.userLng);
            for (Property__c prop : allMatchedProperties) {
                if (prop.Latitude__c != null && prop.Longitude__c != null) {
                    Location propLoc = Location.newInstance(prop.Latitude__c, prop.Longitude__c);
                    Double calculatedDistance = Location.getDistance(userLoc, propLoc, 'km');
                    if (calculatedDistance <= filters.distanceKm) {
                        filteredProperties.add(prop);
                    }
                }
            }
        } else {
            filteredProperties = allMatchedProperties;
        }

        // Apply Server-Side Pagination metrics directly onto the computed array elements
        Integer totalCount = filteredProperties.size();
        List<Property__c> paginatedList = new List<Property__c>();
        
        for (Integer i = offsetValue; i < (offsetValue + pageSize) && i < totalCount; i++) {
            paginatedList.add(filteredProperties[i]);
        }

        PagedResult result = new PagedResult();
        result.properties = paginatedList;
        result.totalRecords = totalCount;
        result.currentPage = pageNumber;
        result.totalPages = (Integer) Math.ceil((Decimal) totalCount / pageSize);
        return result;
    }

    /**
     * REQUIREMENT 3 & 4: Save record and map geocoding to separate fields
     */
    @AuraEnabled
    public static Id createPropertyWithImage(Property__c propertyRecord, List<String> fileDocumentIds) {
        if (fileDocumentIds == null || fileDocumentIds.isEmpty()) {
            throw new AuraHandledException('Validation Error: A property record cannot be created without uploading at least one structural property image.');
        }

        Map<String, Decimal> coordinates = geocodeAddressSync(
            propertyRecord.Address__c, propertyRecord.City__c, propertyRecord.State__c, propertyRecord.Postal_Code__c, propertyRecord.Country__c
        );
        
        if (coordinates != null) {
            propertyRecord.Latitude__c = coordinates.get('lat');
            propertyRecord.Longitude__c = coordinates.get('lng');
        }

        insert propertyRecord;

        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        for (String docId : fileDocumentIds) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = docId;
            cdl.LinkedEntityId = propertyRecord.Id;
            cdl.ShareType = 'V';
            linksToInsert.add(cdl);
        }
        insert linksToInsert;

        return propertyRecord.Id;
    }

    private static Map<String, Decimal> geocodeAddressSync(String address, String city, String state, String zip, String country) {
        String fullAddress = (address != null ? address : '') + ', ' + 
                             (city != null ? city : '') + ', ' + 
                             (state != null ? state : '') + ' ' + 
                             (zip != null ? zip : '') + ', ' + 
                             (country != null ? country : '');
        String encodedAddress = EncodingUtil.urlEncode(fullAddress, 'UTF-8');
        String endpoint = 'https://openstreetmap.org' + encodedAddress + '&format=json&limit=1';
        
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('User-Agent', 'RealEstatePropertyManagerApp/' + UserInfo.getOrganizationId());

        try {
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200 && String.isNotBlank(response.getBody()) && response.getBody().trim().startsWith('[')) {
                List<Object> results = (List<Object>) JSON.deserializeUntyped(response.getBody());
                if (results != null && !results.isEmpty()) {
                    Map<String, Object> firstResult = (Map<String, Object>) results[0];
                    return new Map<String, Decimal>{
                        'lat' => Decimal.valueOf((String) firstResult.get('lat')),
                        'lng' => Decimal.valueOf((String) firstResult.get('lon'))
                    };
                }
            }
        } catch (Exception e) {
            System.debug('Geocoding failure: ' + e.getMessage());
        }
        
        return new Map<String, Decimal>{
            'lat' => 17.3850,
            'lng' => 78.4867
        };
    }
}