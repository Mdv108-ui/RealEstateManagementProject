trigger MaintenanceRequestTrigger on Maintenance_Request__c (before insert, after update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        MaintenanceRequestTriggerHandler.handleBeforeInsert(Trigger.new);
    }
    
}