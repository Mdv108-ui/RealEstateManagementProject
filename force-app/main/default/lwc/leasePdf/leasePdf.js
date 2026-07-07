import { LightningElement, api, wire, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import jsPDFResource from '@salesforce/resourceUrl/jsPDF';
import getLeases from '@salesforce/apex/LeaseAgreementController.getLeases';
import sendLeasePDFEmail from '@salesforce/apex/LeaseAgreementController.sendLeasePDFEmail';

export default class LeasePdfManager extends LightningElement {
    @api recordId;
    @track leaseRecord;
    isJsPdfLoaded = false;

    renderedCallback() {
        if (this.isJsPdfLoaded) return;
        this.isJsPdfLoaded = true;
        
        loadScript(this, jsPDFResource)
            .then(() => {
                console.log('jsPDF library loaded successfully.');
            })
            .catch(error => {
                this.showToast('Resource Loading Error', 'Failed to mount jsPDF layout script engine: ' + error, 'error');
            });
    }

    @wire(getLeases, { leaseIds: '$recordId' })
    wiredLease({ error, data }) {
        if (data) {
            this.leaseRecord = data;
        } else if (error) {
            this.showToast('Error', 'Error fetching record layout parameters', 'error');
        }
    }

    // Client-side Document Construction using standard jsPDF mapping logic
    generatePdfInstance() {
        const { jsPDF } = window.jspdf || window; // Map library module hooks safely
        const doc = new jsPDF({ orientation: 'p', unit: 'mm', format: 'a4' });

        doc.setFont('Helvetica', 'bold');
        doc.setFontSize(22);
        doc.text('FORMAL LEASE AGREEMENT', 20, 25);
        
        doc.setLineWidth(0.5);
        doc.line(20, 30, 190, 30);

        doc.setFont('Helvetica', 'normal');
        doc.setFontSize(12);
        doc.text(`Agreement Reference: ${this.leaseRecord.Name}`, 20, 45);
        doc.text(`Property Name: ${this.leaseRecord.Property__r.Name}`, 20, 55);
        doc.text(`Registered Tenant: ${this.leaseRecord.Tenant__r.Name}`, 20, 65);
        doc.text(`Agreed Monthly Rent: $${this.leaseRecord.Agreed_Monthly_Rent__c} USD / month`, 20, 75);
        doc.text(`Lease Validity Term: ${this.leaseRecord.Start_Date__c} to ${this.leaseRecord.End_Date__c}`, 20, 85);
        
        doc.text('Standard Terms and Conditions Summary:', 20, 105);
        
        // Strip rich text HTML markers safely to extract plain string text for printing
        const cleanTerms = this.leaseRecord.Terms__c ? this.leaseRecord.Terms__c.replace(/<[^>]*>/g, '') : 'No custom terms logged.';
        doc.splitTextToSize(cleanTerms, 170).forEach((line, index) => {
            doc.text(line, 20, 115 + (index * 6));
        });

        return doc;
    }

    handleDownloadPdf() {
        try {
            const doc = this.generatePdfInstance();
            doc.save(`Lease_Agreement_${this.leaseRecord.Name}.pdf`);
            this.showToast('Success', 'PDF generated and downloaded directly to your device.', 'success');
        } catch (error) {
            this.showToast('Generation Failure', 'Client canvas crash: ' + error.message, 'error');
        }
    }

    handleEmailPdf() {
        if (!this.leaseRecord.Tenant__r.Email__c) {
            this.showToast('Data Error', 'The assigned Tenant does not have a valid email address.', 'warning');
            return;
        }

        try {
            const doc = this.generatePdfInstance();
            const rawOutput = doc.output('datauristring'); // Extract canvas as a Base64 stream
            const base64Content = rawOutput.split(',')[1]; // Isolate content from metadata headers Safely

            sendLeasePDFEmail({
                tenantEmail: this.leaseRecord.Tenant__r.Email__c,
                base64Data: base64Content,
                fileName: `Lease_Agreement_${this.leaseRecord.Name}.pdf`,
                tenantName: this.leaseRecord.Tenant__r.Name
            })
            .then(() => {
                this.showToast('Email Dispatched', `Lease document was routed successfully to ${this.leaseRecord.Tenant__r.Email__c}`, 'success');
            })
            .catch(error => {
                this.showToast('Server Error', error.body.message, 'error');
            });
        } catch (error) {
            this.showToast('Processing Error', 'Failed to map email content: ' + error.message, 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
