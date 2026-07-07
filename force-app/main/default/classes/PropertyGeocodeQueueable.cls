public class PropertyGeocodeQueueable implements Queueable, Database.AllowsCallouts {

    private Set<Id> propertyIds;

    public PropertyGeocodeQueueable(Set<Id> propertyIds) {
        this.propertyIds = propertyIds;
    }

    public void execute(QueueableContext context) {

        List<Property__c> properties = [
            SELECT Id, Address__c, City__c, State__c, Postal_Code__c, Country__c
            FROM Property__c
            WHERE Id IN :propertyIds
        ];

        List<Property__c> propertiesToUpdate = new List<Property__c>();

        for (Property__c prop : properties) {

            String fullAddress =
                prop.Address__c + ', ' +
                prop.City__c + ', ' +
                prop.State__c + ', ' +
                prop.Postal_Code__c + ', ' +
                prop.Country__c;

            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(
                'callout:Google_Geocode_API/maps/api/geocode/json?address=' +
                EncodingUtil.urlEncode(fullAddress, 'UTF-8')
            );

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> response =
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                List<Object> results = (List<Object>) response.get('results');

                if (results != null && !results.isEmpty()) {
                    Map<String, Object> firstResult = (Map<String, Object>) results[0];
                    Map<String, Object> geometry = (Map<String, Object>) firstResult.get('geometry');
                    Map<String, Object> location = (Map<String, Object>) geometry.get('location');

                    propertiesToUpdate.add(new Property__c(
                        Id = prop.Id,
                        Geolocation__Latitude__s = Decimal.valueOf(String.valueOf(location.get('lat'))),
                        Geolocation__Longitude__s = Decimal.valueOf(String.valueOf(location.get('lng')))
                    ));
                }
            }
        }

        if (!propertiesToUpdate.isEmpty()) {
            update propertiesToUpdate;
        }
    }
}