@isTest
private class LeaseAgreementControllerTest {

    private class WebServiceMockImpl implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @testSetup
    static void setupTestData() {
        Test.setMock(HttpCalloutMock.class, new WebServiceMockImpl());

        Property__c prop = new Property__c(
            Name = 'Luxury Suite 101',
            Address__c = '789 Main Blvd',
            City__c = 'San Francisco',
            State__c = 'CA',
            Postal_Code__c = '94105',
            Country__c = 'USA',
            Type__c = 'Residential',
            Status__c = 'Occupied',
            Rent__c = 2500.00
        );
        insert prop;

        Tenant__c tenant = new Tenant__c(
            Name = 'John Doe',
            Phone_Number__c = '555-9876',
            Email__c = 'john.doe@example.com'
        );
        insert tenant;

        Test.startTest();
        Lease_Agreement__c lease = new Lease_Agreement__c(
            Agreed_Monthly_Rent__c = 2500.00,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addYears(1),
            Terms__c = 'Standard parameters apply.',
            Tenant__c = tenant.Id,
            Property__c = prop.Id
        );
        insert lease;
        Test.stopTest();
    }

    @isTest
    static void testGetLeasesSuccess() {
        Lease_Agreement__c testLease = [SELECT Id FROM Lease_Agreement__c LIMIT 1];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new WebServiceMockImpl());
        Lease_Agreement__c result = LeaseAgreementController.getLeases(testLease.Id);
        Test.stopTest();

        // Check for record existence instead of hardcoded field metrics
        System.assertNotEquals(null, result, 'Lease record should be successfully fetched');
        System.assertEquals(2500.00, result.Agreed_Monthly_Rent__c, 'Rent value should match setup data');
    }

    @isTest
    static void testGetLeasesException() {
        Id fakeLeaseId = Id.valueOf(Lease_Agreement__c.sObjectType.getDescribe().getKeyPrefix() + '000000000000');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new WebServiceMockImpl());
        try {
            LeaseAgreementController.getLeases(fakeLeaseId);
            System.assert(false, 'An exception should have been thrown for an invalid ID');
        } catch (Exception e) {
            // Generalised check: Verify that an exception was thrown and caught safely
            System.assertNotEquals(null, e.getMessage(), 'An exception message should be present');
        }
        Test.stopTest();
    }

    @isTest
    static void testSendLeasePDFEmailSuccess() {
        String targetEmail = 'john.doe@example.com';
        String mockBase64Pdf = EncodingUtil.base64Encode(Blob.valueOf('Mock PDF Content'));
        String fileName = 'Lease_Agreement_Document.pdf';
        String tenantName = 'John Doe';

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new WebServiceMockImpl());
        
        try {
            LeaseAgreementController.sendLeasePDFEmail(targetEmail, mockBase64Pdf, fileName, tenantName);
            System.assert(true, 'Method executed successfully without throwing any uncaught exceptions');
        } catch (Exception e) {
            System.assert(false, 'The method should not throw an exception under standard working conditions: ' + e.getMessage());
        }
        
        Test.stopTest();
    }

    @isTest
    static void testSendLeasePDFEmailBlankEmailError() {
        String mockBase64Pdf = EncodingUtil.base64Encode(Blob.valueOf('Mock PDF Content'));
        String fileName = 'Lease_Agreement_Document.pdf';
        String tenantName = 'John Doe';

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new WebServiceMockImpl());
        try {
            LeaseAgreementController.sendLeasePDFEmail('', mockBase64Pdf, fileName, tenantName);
            System.assert(false, 'Should have blocked execution due to empty email string');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'An error message should be returned');
        }
        Test.stopTest();
    }

    @isTest
    static void testSendLeasePDFEmailProcessingException() {
        String targetEmail = 'john.doe@example.com';
        String corruptBase64Pdf = '!!! Invalid Base 64 !!!'; 
        String fileName = 'Lease_Agreement_Document.pdf';
        String tenantName = 'John Doe';

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new WebServiceMockImpl());
        try {
            LeaseAgreementController.sendLeasePDFEmail(targetEmail, corruptBase64Pdf, fileName, tenantName);
            System.assert(false, 'Should have failed during base64 decoding phase');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'A decoding error should have been caught');
        }
        Test.stopTest();
    }
}