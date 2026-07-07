public class LeaseExpiryNotificationBatch implements Database.Batchable<sObject>,Schedulable {
    public Database.QueryLocator start(Database.BatchableContext bc){
        Date ExpiryOneMonth =Date.today().addDays(30);
        Date ExpiryOneDay =Date.today().addDays(1);
        return Database.getQueryLocator([SELECT Id,Name,End_Date__c,Tenant__r.Name,Tenant__r.Email__c,Property__r.Name FROM Lease_Agreement__c
                                        WHERE Tenant__r.Email__c != null AND (End_Date__c=:ExpiryOneMonth OR End_Date__c =:ExpiryOneDay)]);
        
        
    }
    public void execute(Database.BatchableContext bc,list<Lease_Agreement__c> scope){
        List<Messaging.SingleEmailMessage> sendToAlert =new List<Messaging.SingleEmailMessage>();
        Date todayDate = Date.today();
        for(Lease_Agreement__c lease:scope){
            Integer daysRemaining = todayDate.daysBetween(lease.End_Date__c);
            Messaging.SingleEmailMessage mail= new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] {lease.Tenant__r.Email__c});
            if(daysRemaining == 30){
               mail.setSubject('Lease Agreement Renewal Reminder - 30 Days Remaining');
                mail.setPlainTextBody('Hello ' + lease.Tenant__r.Name + ',\n\nThis is an automated reminder that your lease agreement for ' + lease.Property__r.Name + ' is scheduled to expire in exactly 1 month on ' + lease.End_Date__c + '. Please contact management to discuss renewal options.');
                
            }
            else if(daysRemaining == 1){
                mail.setSubject('URGENT: Your Lease Agreement Expires Tomorrow');
                mail.setPlainTextBody('Hello ' + lease.Tenant__r.Name + ',\n\nThis is an urgent notification that your lease agreement for ' + lease.Property__r.Name + ' expires tomorrow on ' + lease.End_Date__c + '. If you have not arranged an exit strategy or lease extension, please reach out to the office immediately.');
                
            }
            sendToAlert.add(mail);
        }
        if(!sendToAlert.isEmpty()){
            Messaging.sendEmail(sendToAlert);
        }
    }
    public void finish(Database.BatchableContext bc) {
        System.debug('Lease Expiry Automation Engine successfully finalized daily runtime sweeps.');
    }
    public void execute(SchedulableContext sc){
        Database.executeBatch(new LeaseExpiryNotificationBatch(), 100);
    }
    

}