public with sharing class LeaseAgreementController {

    @AuraEnabled(cacheable=true)
    public static Lease_Agreement__c getLeases(Id leaseIds) {
        if (leaseIds == null) {
            throw new AuraHandledException('Invalid or missing Lease Agreement Identifier.');
        }
        try {
            return [
                SELECT Id, Name, Agreed_Monthly_Rent__c, Start_Date__c, End_Date__c, Terms__c,
                       Tenant__r.Name, Tenant__r.Email__c, Property__r.Name 
                FROM Lease_Agreement__c 
                WHERE Id = :leaseIds 
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error pulling lease details: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void sendLeasePDFEmail(String tenantEmail, String base64Data, String fileName, String tenantName) {
        if (String.isBlank(tenantEmail)) {
            throw new AuraHandledException('The target Tenant record does not have a valid email address populated.');
        }
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('Cannot send email. The generated PDF data payload is empty.');
        }

        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { tenantEmail });
            mail.setSubject('Your Formal Lease Agreement Document');
            mail.setPlainTextBody('Hello ' + tenantName + ',\n\nPlease find attached a digital copy of your formal Lease Agreement. Let us know if you have any questions.\n\nBest regards,\nProperty Management Team');
            
            // Decode the Base64 client-side payload into a binary file blob
            Blob pdfBlob = EncodingUtil.base64Decode(base64Data);
            
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(fileName);
            attachment.setBody(pdfBlob);
            attachment.setContentType('application/pdf');

            mail.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

        } catch (Exception e) {
            throw new AuraHandledException('Failed to process and mail out the PDF document: ' + e.getMessage());
        }
    }
}
