public with sharing class VendorController {

    public class VendorWrapper {
        @AuraEnabled public List<Vendor__c> records { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
    }

    /**
     * Fetches all registered service vendors tracked in the platform database.
     */
    @AuraEnabled(cacheable=true)
    public static VendorWrapper getVendors(Integer pageNumber, Integer pageSize) {
        if (pageNumber == null || pageNumber < 1) pageNumber = 1;
        if (pageSize == null || pageSize < 1) pageSize = 25;
        
        Integer offsetValue = (pageNumber - 1) * pageSize;
        
        VendorWrapper wrapper = new VendorWrapper();
        
        // Count overall system entries
        wrapper.totalRecords = Database.countQuery('SELECT COUNT() FROM Vendor__c');
        
        // Pull paginated vendor listing records [1]
        wrapper.records = [
            SELECT Id, Name, Phone_Number__c, Email__c, CreatedDate 
            FROM Vendor__c 
            ORDER BY Name ASC 
            LIMIT :pageSize 
            OFFSET :offsetValue
        ];
        
        return wrapper;
    }

    /**
     * Saves a new vendor record, explicitly enforcing property validation inputs.
     */
    @AuraEnabled
    public static Id createVendor(Vendor__c vendorRecord) {
        if (vendorRecord == null) {
            throw new AuraHandledException('Vendor detail parameters cannot be empty.');
        }
        if (String.isBlank(vendorRecord.Name)) {
            throw new AuraHandledException('Vendor Name is strictly required.');
        }
        if (String.isBlank(vendorRecord.Phone_Number__c)) {
            throw new AuraHandledException('Vendor Phone Number is strictly required.');
        }
        if (String.isBlank(vendorRecord.Email__c)) {
            throw new AuraHandledException('Vendor Email Address is strictly required.');
        }

        try {
            insert vendorRecord;
            return vendorRecord.Id;
        } catch (DmlException e) {
            throw new AuraHandledException('Database transaction failed: ' + e.getDmlMessage(0));
        }
    }
}