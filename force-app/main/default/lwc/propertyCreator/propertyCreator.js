import { LightningElement } from 'lwc';
import createPropertyWithImages from '@salesforce/apex/PropertyController.createPropertyWithImages';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CreateProperty extends LightningElement {
    propertyRecord = {};
    files = [];

    typeOptions = [
        { label: 'Residential', value: 'Residential' },
        { label: 'Commercial', value: 'Commercial' }
    ];

    furnishingOptions = [
        { label: 'Furnished', value: 'Furnished' },
        { label: 'Semi-Furnished', value: 'Semi-Furnished' },
        { label: 'Unfurnished', value: 'Unfurnished' }
    ];

    statusOptions = [
        { label: 'Available', value: 'Available' },
        { label: 'Occupied', value: 'Occupied' }
    ];

    handleName(event) {
        this.propertyRecord.Name = event.target.value;
    }

    handleAddress(event) {
        this.propertyRecord.Address__c = event.target.value;
    }

    handleCity(event) {
        this.propertyRecord.City__c = event.target.value;
    }

    handleState(event) {
        this.propertyRecord.State__c = event.target.value;
    }

    handlePostalCode(event) {
        this.propertyRecord.Postal_Code__c = event.target.value;
    }

    handleCountry(event) {
        this.propertyRecord.Country__c = event.target.value;
    }

    handleType(event) {
        this.propertyRecord.Type__c = event.detail.value;
    }

    handleFurnishing(event) {
        this.propertyRecord.Furnishing_Status__c = event.detail.value;
    }

    handleStatus(event) {
        this.propertyRecord.Status__c = event.detail.value;
    }

    handleRent(event) {
        this.propertyRecord.Rent__c = event.target.value;
    }

    handleDescription(event) {
        this.propertyRecord.Description__c = event.target.value;
    }

    handleFiles(event) {
        this.files = [];

        Array.from(event.target.files).forEach(file => {
            const reader = new FileReader();

            reader.onload = () => {
                const base64 = reader.result.split(',')[1];

                this.files = [
                    ...this.files,
                    {
                        fileName: file.name,
                        base64Data: base64
                    }
                ];
            };

            reader.readAsDataURL(file);
        });
    }

    saveProperty() {
        if (!this.files || this.files.length === 0 || !this.files[0].base64Data) {
            this.showToast('Error', 'Please upload at least one image.', 'error');
            return;
        }

        createPropertyWithImages({
            propertyRecord: this.propertyRecord,
            files: this.files
        })
            .then(() => {
                this.showToast('Success', 'Property created successfully.', 'success');
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error.body ? error.body.message : error.message,
                    'error'
                );
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}