@isTest
private class TenantControllerTest {

    @testSetup
    static void setupTestData() {
        // Create 5 test Tenant records with mock contact details
        List<Tenant__c> testTenants = new List<Tenant__c>();
        
        testTenants.add(new Tenant__c(Name = 'Charlie Tenant', Phone_Number__c = '555-0003', Email__c = 'charlie@test.com'));
        testTenants.add(new Tenant__c(Name = 'Alpha Tenant', Phone_Number__c = '555-0001', Email__c = 'alpha@test.com'));
        testTenants.add(new Tenant__c(Name = 'Delta Tenant', Phone_Number__c = '555-0004', Email__c = 'delta@test.com'));
        testTenants.add(new Tenant__c(Name = 'Beta Tenant', Phone_Number__c = '555-0002', Email__c = 'beta@test.com'));
        
        insert testTenants;
    }

    @isTest
    static void testGetTenantsSuccess() {
        Test.startTest();
        List<Tenant__c> result = TenantController.getTenants();
        Test.stopTest();

        // 1. Verify that records were returned
        System.assertNotEquals(null, result, 'The returned list should not be null.');
        System.assertEquals(4, result.size(), 'Should return exactly 4 tenant records.');

        // 2. Verify alphabetical ordering (ORDER BY Name ASC)
        System.assertEquals('Alpha Tenant', result[0].Name, 'First record should be Alpha Tenant.');
        System.assertEquals('Beta Tenant', result[1].Name, 'Second record should be Beta Tenant.');
        System.assertEquals('Charlie Tenant', result[2].Name, 'Third record should be Charlie Tenant.');
        System.assertEquals('Delta Tenant', result[3].Name, 'Fourth record should be Delta Tenant.');

        // 3. Verify fields required by the LWC component are populated
        System.assertNotEquals(null, result[0].Phone_Number__c, 'Phone number should be queried.');
        System.assertNotEquals(null, result[0].Email__c, 'Email address should be queried.');
        System.assertNotEquals(null, result[0].CreatedDate, 'CreatedDate should be queried.');
    }

    @isTest
    static void testGetTenantsEmptyDatabase() {
        // Clean out the setup data to test an empty state scenario
        delete [SELECT Id FROM Tenant__c];

        Test.startTest();
        List<Tenant__c> result = TenantController.getTenants();
        Test.stopTest();

        // Verify it returns an empty list gracefully rather than failing
        System.assertNotEquals(null, result, 'Should return an empty list object instead of null.');
        System.assertEquals(0, result.size(), 'The list size should be 0.');
    }
}