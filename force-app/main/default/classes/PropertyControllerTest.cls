@isTest
private class PropertyControllerTest {

    @testSetup
    static void setupTestData() {
        List<Property__c> propertiesToInsert = new List<Property__c>();
        
        for (Integer i = 0; i < 30; i++) {
            Property__c prop = new Property__c(
                Name = 'Test Property ' + i,
                Address__c = '123 Main St',
                City__c = 'San Francisco',
                State__c = 'CA',
                Postal_Code__c = '94105',
                Country__c = 'USA',
                Type__c = 'Residential',
                Rent__c = 1000 + (i * 100), // Rents range from 1000 to 3900
                Status__c = (Math.mod(i, 2) == 0) ? 'Available' : 'Occupied',
                Furnishing_Status__c = 'Furnished',
                // Explicitly set matching decimal nodes for proximity calculations
                Latitude__c = 37.7749,
                Longitude__c = -122.4194
            );
            propertiesToInsert.add(prop);
        }
        insert propertiesToInsert;
    }

    /**
     * Tests Requirement 2.a: Verifies server-side pagination splits results 
     * exactly into 25-record page segments.
     */
    @isTest
    static void testServerSidePagination() {
        PropertyController.FilterWrapper emptyFilters = new PropertyController.FilterWrapper();
        String filtersJson = JSON.serialize(emptyFilters);

        Test.startTest();
        PropertyController.PagedResult page1 = PropertyController.getPagedProperties(1, filtersJson);
        PropertyController.PagedResult page2 = PropertyController.getPagedProperties(2, filtersJson);
        Test.stopTest();

        System.assertEquals(30, page1.totalRecords, 'Total record count index calculation is wrong.');
        System.assertEquals(25, page1.properties.size(), 'Page size limit was not constrained to 25 items.');
        System.assertEquals(5, page2.properties.size(), 'Remaining trailing page records count is wrong.');
    }

    /**
     * Tests Requirement 2.b: Verifies complex filtering configurations and 
     * error-free Apex Location in-memory proximity matching.
     */
    @isTest
    static void testComplexPropertyFiltering() {
        PropertyController.FilterWrapper filters = new PropertyController.FilterWrapper();
        filters.minPrice = 1000;
        filters.maxPrice = 2000;
        filters.status = 'Available';
        filters.furnishingStatus = 'Furnished';
        
        // Target exact testing matching coordinates matrix
        filters.userLat = 37.7749;
        filters.userLng = -122.4194;
        filters.distanceKm = 10;

        String filtersJson = JSON.serialize(filters);

        Test.startTest();
        PropertyController.PagedResult result = PropertyController.getPagedProperties(1, filtersJson);
        Test.stopTest();

        System.assertNotEquals(0, result.properties.size(), 'In-memory location tracking mapping filter failed.');
        for (Property__c prop : result.properties) {
            System.assertEquals('Available', prop.Status__c);
            System.assertEquals('Furnished', prop.Furnishing_Status__c);
            System.assert(prop.Rent__c >= 1000 && prop.Rent__c <= 2000);
        }
    }

    /**
     * Tests Requirement 3 & 4: Validates normal property saving behavior, including 
     * mock Callout routing to set coordinates, and linking file documents.
     */
    @isTest
    static void testCreatePropertySuccess() {
        Test.setMock(HttpCalloutMock.class, new GeocodingHttpMockGenerator());

        ContentVersion cv = new ContentVersion(
            Title = 'Property Image Base',
            PathOnClient = 'testImage.jpg',
            VersionData = Blob.valueOf('Mock Binary Image Stream Content'),
            IsMajorVersion = true
        );
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        List<String> fileDocumentIds = new List<String>{ docId };

        Property__c newProp = new Property__c(
            Name = 'New Villa Estate',
            Address__c = '100 Broadway',
            City__c = 'New York',
            State__c = 'NY',
            Postal_Code__c = '10005',
            Country__c = 'USA',
            Type__c = 'Residential',
            Rent__c = 5000,
            Status__c = 'Available',
            Furnishing_Status__c = 'Furnished'
        );

        Test.startTest();
        Id generatedPropId = PropertyController.createPropertyWithImage(newProp, fileDocumentIds);
        Test.stopTest();

        System.assertNotEquals(null, generatedPropId);
        Property__c savedRecord = [SELECT Id, Latitude__c, Longitude__c FROM Property__c WHERE Id = :generatedPropId];
        System.assertEquals(40.7128, savedRecord.Latitude__c);
        System.assertEquals(-74.0060, savedRecord.Longitude__c);
    }

    /**
     * Tests Requirement 3: Verifies that creating a property fails and throws an error 
     * if no images are attached.
     */
    @isTest
    static void testCreatePropertyValidationException() {
        Property__c invalidProp = new Property__c(
            Name = 'No Image Estate',
            Address__c = 'Void Way'
        );

        Test.startTest();
        try {
            PropertyController.createPropertyWithImage(invalidProp, new List<String>());
            System.assert(false, 'Validation layer missed throwing exception.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()), 'Exception caught successfully.');
        }
        Test.stopTest();
    }

    /**
     * Tests Geocoding Fallback Block: Verifies that if an API throws a non-200 code, 
     * the system applies your default Hyderabad coordinates seamlessly.
     */
    @isTest
    static void testGeocodingCalloutFallback() {
        GeocodingHttpMockGenerator failureMock = new GeocodingHttpMockGenerator();
        failureMock.statusCode = 500;
        Test.setMock(HttpCalloutMock.class, failureMock);

        ContentVersion cv = new ContentVersion(
            Title = 'Property Fallback Image',
            PathOnClient = 'testImage.jpg',
            VersionData = Blob.valueOf('Mock Binary Image Stream Content'),
            IsMajorVersion = true
        );
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        List<String> fileDocumentIds = new List<String>{ docId };

        Property__c fallbackProp = new Property__c(
            Name = 'Fallback Estate',
            Address__c = 'Broken API St',
            City__c = 'Nowhere',
            State__c = 'NW',
            Postal_Code__c = '00000',
            Country__c = 'Void',
            Type__c = 'Residential',
            Rent__c = 1500,
            Status__c = 'Available',
            Furnishing_Status__c = 'Unfurnished'
        );

        Test.startTest();
        Id generatedPropId = PropertyController.createPropertyWithImage(fallbackProp, fileDocumentIds);
        Test.stopTest();

        Property__c savedRecord = [SELECT Id, Latitude__c, Longitude__c FROM Property__c WHERE Id = :generatedPropId];
        System.assertEquals(17.3850, savedRecord.Latitude__c);
        System.assertEquals(78.4867, savedRecord.Longitude__c);
    }

    /**
     * Internal Mock class to manage HTTP geocoding API responses.
     */
    private class GeocodingHttpMockGenerator implements HttpCalloutMock {
        public Integer statusCode = 200;
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            if (this.statusCode == 200) {
                response.setBody('[{"lat": "40.7128", "lon": "-74.0060"}]');
            } else {
                response.setBody('Internal Server Error');
            }
            response.setStatusCode(this.statusCode);
            return response;
        }
    }
}