public class TenantController {
    @AuraEnabled(cacheable=true)
    public static list<Tenant__c> getTenants(){
        try{
          return [SELECT Id,Name,Phone_Number__c,Email__c,CreatedDate FROM Tenant__c ORDER BY Name ASC LIMIT 100];  
        }
        catch(Exception e){
            throw new AuraHandledException('Error fetching tenant registries: ' + e.getMessage());
        }
    }

}