public class MaintenanceRequestTriggerHandler {

    public static void handleBeforeInsert(List<Maintenance_Request__c> newRequests) {

        List<Maintenance_Request__c> requestsToAssign = new List<Maintenance_Request__c>();

        for (Maintenance_Request__c req : newRequests) {
            if (req.Vendor__c == null) {
                requestsToAssign.add(req);
            }

            if (String.isBlank(req.Status__c)) {
                req.Status__c = 'Open';
            }
        }

        if (requestsToAssign.isEmpty()) {
            return;
        }

        List<Vendor__c> allVendors = [
            SELECT Id
            FROM Vendor__c
        ];

        if (allVendors.isEmpty()) {
            return;
        }

        Map<Id, Integer> vendorWorkloadMap = new Map<Id, Integer>();

        for (Vendor__c vendor : allVendors) {
            vendorWorkloadMap.put(vendor.Id, 0);
        }

        for (AggregateResult ar : [
            SELECT Vendor__c vendorId, COUNT(Id) activeCount
            FROM Maintenance_Request__c
            WHERE Vendor__c != null
            AND Status__c IN ('Open', 'In progress')
            GROUP BY Vendor__c
        ]) {
            Id vendorId = (Id) ar.get('vendorId');
            Integer activeCount = (Integer) ar.get('activeCount');

            if (vendorWorkloadMap.containsKey(vendorId)) {
                vendorWorkloadMap.put(vendorId, activeCount);
            }
        }

        for (Maintenance_Request__c req : requestsToAssign) {
            Id leastBusyVendorId;
            Integer minWorkload = 2147483647;

            for (Id vendorId : vendorWorkloadMap.keySet()) {
                Integer currentWorkload = vendorWorkloadMap.get(vendorId);

                if (currentWorkload < minWorkload) {
                    minWorkload = currentWorkload;
                    leastBusyVendorId = vendorId;
                }
            }

            if (leastBusyVendorId != null) {
                req.Vendor__c = leastBusyVendorId;
                vendorWorkloadMap.put(leastBusyVendorId, minWorkload + 1);
            }
        }
    }
}