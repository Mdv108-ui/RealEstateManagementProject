trigger PropertyTrigger on Property__c (after insert, after update) {

    Set<Id> propertyIds = new Set<Id>();

    for (Property__c prop : Trigger.new) {

        if (Trigger.isInsert) {
            propertyIds.add(prop.Id);
        }

        if (Trigger.isUpdate) {
            Property__c oldProp = Trigger.oldMap.get(prop.Id);

            if (
                prop.Address__c != oldProp.Address__c ||
                prop.City__c != oldProp.City__c ||
                prop.State__c != oldProp.State__c ||
                prop.Postal_Code__c != oldProp.Postal_Code__c ||
                prop.Country__c != oldProp.Country__c
            ) {
                propertyIds.add(prop.Id);
            }
        }
    }

    if (!propertyIds.isEmpty()) {
        System.enqueueJob(new PropertyGeocodeQueueable(propertyIds));
    }
}