@IsTest
public class MaintenanceRequestTriggerHandlerTest {

    private class MockGeocodeResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"results":[{"geometry":{"location":{"lat":17.3850,"lng":78.4867}}}]}');
            return res;
        }
    }

    @IsTest
    static void testAssignVendorWithLeastWorkload() {
        Test.setMock(HttpCalloutMock.class, new MockGeocodeResponse());

        Property__c property = new Property__c(
            Name = 'Test Property',
            Address__c = 'Hyderabad',
            City__c = 'Hyderabad',
            State__c = 'Telangana',
            Postal_Code__c = '500001',
            Country__c = 'India',
            Type__c = 'Residential',
            Status__c = 'Available',
            Rent__c = 25000,
            Description__c = 'Test property'
        );
        insert property;

        Vendor__c vendor1 = new Vendor__c(
            Name = 'Vendor One',
            Phone_Number__c = '9999999991',
            Email__c = 'vendor1@test.com'
        );

        Vendor__c vendor2 = new Vendor__c(
            Name = 'Vendor Two',
            Phone_Number__c = '9999999992',
            Email__c = 'vendor2@test.com'
        );

        insert new List<Vendor__c>{ vendor1, vendor2 };

        insert new Maintenance_Request__c(
            Property__c = property.Id,
            Vendor__c = vendor1.Id,
            Status__c = 'Open',
            Description__c = 'Old request assigned to Vendor One'
        );

        Maintenance_Request__c newRequest = new Maintenance_Request__c(
            Property__c = property.Id,
            Status__c = 'Open',
            Description__c = 'New request should assign to Vendor Two'
        );

        Test.startTest();
        insert newRequest;
        Test.stopTest();

        Maintenance_Request__c insertedRequest = [
            SELECT Id, Vendor__c, Status__c
            FROM Maintenance_Request__c
            WHERE Id = :newRequest.Id
        ];

        System.assertEquals(vendor2.Id, insertedRequest.Vendor__c);
        System.assertEquals('Open', insertedRequest.Status__c);
    }

    @IsTest
    static void testDefaultStatusAndVendorAssignment() {
        Test.setMock(HttpCalloutMock.class, new MockGeocodeResponse());

        Property__c property = new Property__c(
            Name = 'Test Property 2',
            Address__c = 'Madhapur',
            City__c = 'Hyderabad',
            State__c = 'Telangana',
            Postal_Code__c = '500081',
            Country__c = 'India',
            Type__c = 'Commercial',
            Status__c = 'Available',
            Rent__c = 50000,
            Description__c = 'Commercial property'
        );
        insert property;

        Vendor__c vendor = new Vendor__c(
            Name = 'Vendor Default',
            Phone_Number__c = '9999999993',
            Email__c = 'vendordefault@test.com'
        );
        insert vendor;

        Maintenance_Request__c request = new Maintenance_Request__c(
            Property__c = property.Id,
            Description__c = 'Status should become Open automatically'
        );

        Test.startTest();
        insert request;
        Test.stopTest();

        Maintenance_Request__c insertedRequest = [
            SELECT Id, Vendor__c, Status__c
            FROM Maintenance_Request__c
            WHERE Id = :request.Id
        ];

        System.assertEquals(vendor.Id, insertedRequest.Vendor__c);
        System.assertEquals('Open', insertedRequest.Status__c);
    }

    @IsTest
    static void testNoVendorAvailable() {
        Test.setMock(HttpCalloutMock.class, new MockGeocodeResponse());

        Property__c property = new Property__c(
            Name = 'Test Property 3',
            Address__c = 'Kukatpally',
            City__c = 'Hyderabad',
            State__c = 'Telangana',
            Postal_Code__c = '500072',
            Country__c = 'India',
            Type__c = 'Residential',
            Status__c = 'Available',
            Rent__c = 18000,
            Description__c = 'No vendor test property'
        );
        insert property;

        Maintenance_Request__c request = new Maintenance_Request__c(
            Property__c = property.Id,
            Status__c = 'Open',
            Description__c = 'No vendor available'
        );

        Test.startTest();
        insert request;
        Test.stopTest();

        Maintenance_Request__c insertedRequest = [
            SELECT Id, Vendor__c, Status__c
            FROM Maintenance_Request__c
            WHERE Id = :request.Id
        ];

        System.assertEquals(null, insertedRequest.Vendor__c);
        System.assertEquals('Open', insertedRequest.Status__c);
    }

    @IsTest
    static void testBulkAssignment() {
        Test.setMock(HttpCalloutMock.class, new MockGeocodeResponse());

        Property__c property = new Property__c(
            Name = 'Bulk Test Property',
            Address__c = 'Gachibowli',
            City__c = 'Hyderabad',
            State__c = 'Telangana',
            Postal_Code__c = '500032',
            Country__c = 'India',
            Type__c = 'Residential',
            Status__c = 'Available',
            Rent__c = 30000,
            Description__c = 'Bulk test property'
        );
        insert property;

       Vendor__c vendor1 = new Vendor__c(
    Name = 'Vendor One',
    Phone_Number__c = '9999999991',
    Email__c = 'vendor1@test.com'
);

Vendor__c vendor2 = new Vendor__c(
    Name = 'Vendor Two',
    Phone_Number__c = '9999999992',
    Email__c = 'vendor2@test.com'
);
        insert new List<Vendor__c>{ vendor1, vendor2 };

        List<Maintenance_Request__c> requests = new List<Maintenance_Request__c>();

        for (Integer i = 0; i < 10; i++) {
            requests.add(new Maintenance_Request__c(
                Property__c = property.Id,
                Status__c = 'Open',
                Description__c = 'Bulk request ' + i
            ));
        }

        Test.startTest();
        insert requests;
        Test.stopTest();

        List<Maintenance_Request__c> insertedRequests = [
            SELECT Id, Vendor__c, Status__c
            FROM Maintenance_Request__c
            WHERE Property__c = :property.Id
        ];

        System.assertEquals(10, insertedRequests.size());

        for (Maintenance_Request__c req : insertedRequests) {
            System.assertNotEquals(null, req.Vendor__c);
            System.assertEquals('Open', req.Status__c);
        }
    }
}