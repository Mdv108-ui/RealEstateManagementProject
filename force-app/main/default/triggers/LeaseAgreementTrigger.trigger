trigger LeaseAgreementTrigger on Lease_Agreement__c (after insert) {
    if(Trigger.isAfter && Trigger.isInsert){
        LeaseAgreementTriggerHandler.handleAfterInsert(Trigger.new);
    }

}