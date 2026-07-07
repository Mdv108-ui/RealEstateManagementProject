public class LeaseAgreementTriggerHandler {
    public static void handleAfterInsert(list<Lease_Agreement__c> newLeases){
        list<Task> taskList= new list<Task>();
        for(Lease_Agreement__c leases:newLeases){
            if(leases.Tenant__c != null && leases.Property__c != null){
                Task task=new Task();
                task.Subject='Generate Lease Agreement';
                task.Priority= 'High';
                task.Status='Not Started';
                task.ActivityDate=Date.today().addDays(7);
                task.WhatId=leases.Id;
                task.Description = 'Automated Alert: A new property has been assigned to this tenant. Please compile, verify, and generate the formal Lease Agreement document.';
                taskList.add(task);
                                                    
            }
        }
        if(!taskList.isEmpty()){
            insert taskList;
        }
        
    }

}