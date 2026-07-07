import { LightningElement,wire,track} from 'lwc';
import getTenants from '@salesforce/apex/TenantController.getTenants';


export default class TenantListView extends LightningElement {
    @track tenants;
    columns=[{label:'Tenant Name',fieldName:'Name',type:'text',sortable:true},{label:'Phone Number',fieldName:'Phone_Number__c',type:'phone'},{label:'Email',fieldName:'Email__c',type:'email'},{label:'Registration Date',fieldName:'CreatedDate',type:'date',typeAttributes:{year:'numeric',month:'short',day:'2-digit'}}];
    @wire(getTenants)
    wiredTenants({error,data}){
        if(data){
            this,tenants=data;

        }else if(error){
            console.error('Error fetching tenants:',error);
            
        }
    }
}
