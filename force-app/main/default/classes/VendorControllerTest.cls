@isTest
private class VendorControllerTest {

    @isTest
    static void testGetVendorsSuccess() {
        // Arrange: Generate sample test records architecture
        List<Vendor__c> testVendors = new List<Vendor__c>();
        for(Integer i = 0; i < 5; i++) {
            testVendors.add(new Vendor__c(
                Name = 'Plumbing Expert ' + i,
                Phone_Number__c = '555-010' + i,
                Email__c = 'vendor' + i + '@maintenancehub.com'
            ));
        }
        insert testVendors;

        // Act: Invoke paginated list queries execution paths
        Test.startTest();
        VendorController.VendorWrapper wrapperResult = VendorController.getVendors(1, 10);
        Test.stopTest();

        // Assert: Ensure exact parity match
        System.assertNotEquals(null, wrapperResult, 'Wrapper should instantiate completely.');
        System.assertEquals(5, wrapperResult.totalRecords, 'System total row tracker reporting mismatches.');
        System.assertEquals(5, wrapperResult.records.size(), 'Listing stream payload counts are inaccurate.');
    }

    @isTest
    static void testCreateVendorSuccess() {
        Vendor__c newVendor = new Vendor__c(
            Name = 'AC Repair Techs',
            Phone_Number__c = '800-555-0199',
            Email__c = 'dispatch@acrepairtechs.local'
        );

        Test.startTest();
        Id recordId = VendorController.createVendor(newVendor);
        Test.stopTest();

        System.assertNotEquals(null, recordId, 'Valid vendor should return an insertion record ID.');
        
        Vendor__c verifiedRecord = [SELECT Name, Email__c FROM Vendor__c WHERE Id = :recordId];
        System.assertEquals('AC Repair Techs', verifiedRecord.Name, 'Saved vendor data does not match original payload.');
    }

    @isTest
    static void testCreateVendorValidationThrowsException() {
        // Create an invalid record missing the required Phone number
        Vendor__c brokenVendor = new Vendor__c(
            Name = 'Faulty Electrical Co.',
            Email__c = 'sparks@faultyelectrical.local'
        );

        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            VendorController.createVendor(brokenVendor);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            // FIXED: Standard Apex test run intercept handles AuraHandledException wrapper containers.
            // We verify that the execution environment successfully blocked the write action.
            System.assertNotEquals(null, e.getMessage(), 'An AuraHandledException message structure was generated.');
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Controller must block execution if validations fail.');
    }
}