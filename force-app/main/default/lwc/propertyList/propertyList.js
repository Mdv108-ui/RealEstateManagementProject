import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPagedProperties from '@salesforce/apex/PropertyController.getPagedProperties';
import createPropertyWithImage from '@salesforce/apex/PropertyController.createPropertyWithImage';

export default class PropertyManagementHub extends LightningElement {
    @track propertiesList = [];
    @track mapMarkers = [];
    @track uploadedFileIds = [];
    
    pageNumber = 1;
    totalPages = 1;
    totalRecords = 0;

    filterState = { minPrice: null, maxPrice: null, status: '', furnishingStatus: '', distanceKm: null, userLat: null, userLng: null };

    // CRUCIAL: Ensure these labels and values match your Salesforce Picklist API values exactly!
    typeOptions = [{ label: 'Residential', value: 'Residential' }, { label: 'Commercial', value: 'Commercial' }];
    statusOptionsWithoutAll = [{ label: 'Available', value: 'Available' }, { label: 'Occupied', value: 'Occupied' }];
    statusOptionsWithAll = [{ label: 'All', value: '' }, { label: 'Available', value: 'Available' }, { label: 'Occupied', value: 'Occupied' }];
    furnishingOptions = [{ label: 'Furnished', value: 'Furnished' }, { label: 'Semi-Furnished', value: 'Semi-Furnished' }, { label: 'Unfurnished', value: 'Unfurnished' }];
    furnishingOptionsWithAll = [{ label: 'All', value: '' }, { label: 'Furnished', value: 'Furnished' }, { label: 'Semi-Furnished', value: 'Semi-Furnished' }, { label: 'Unfurnished', value: 'Unfurnished' }];
    acceptedFormats = ['.png', '.jpg', '.jpeg'];

    columns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'Address', fieldName: 'Address__c', type: 'text' },
        { label: 'City', fieldName: 'City__c', type: 'text' },
        { label: 'Rent Price', fieldName: 'Rent__c', type: 'currency' },
        { label: 'Status', fieldName: 'Status__c', type: 'text' }
    ];

    connectedCallback() {
        this.loadProperties();
    }

    loadProperties() {
        getPagedProperties({ pageNumber: this.pageNumber, filtersJson: JSON.stringify(this.filterState) })
            .then(result => {
                this.propertiesList = result.properties;
                this.totalRecords = result.totalRecords;
                this.totalPages = result.totalPages || 1;
            })
            .catch(error => this.showToast('Server Request Failure', error.body.message, 'error'));
    }

    fetchBrowserCoordinates() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition((position) => {
                this.filterState.userLat = position.coords.latitude;
                this.filterState.userLng = position.coords.longitude;
                this.showToast('Success', 'User coordinates accurately initialized.', 'success');
                this.pageNumber = 1;
                this.loadProperties();
            }, (err) => {
                this.showToast('Location Flag Blocked', 'Unable to retrieve location permission details.', 'error');
            });
        } else {
            this.showToast('Not Supported', 'Browser does not feature standard geolocation tracking APIs.', 'warning');
        }
    }

    handleFilterChange(event) {
        const fieldName = event.target.dataset.field;
        this.filterState[fieldName] = event.target.value;
        this.pageNumber = 1; 
        this.loadProperties();
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows && selectedRows.length > 0) {
            const activeRow = selectedRows[0]; 

            const rowLat = activeRow.Latitude__c;
            const rowLng = activeRow.Longitude__c;

            if (rowLat && rowLng) {
                this.mapMarkers = [{
                    location: {
                        Latitude: parseFloat(rowLat),
                        Longitude: parseFloat(rowLng)
                    },
                    title: activeRow.Name,
                    description: `${activeRow.Address__c || ''}, ${activeRow.City__c || ''}`
                }];
            } else {
                this.mapMarkers = [];
                this.showToast('Map Trace Empty', 'Geocoding values missing on this record.', 'warning');
            }
        }
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        let fileIds = [...this.uploadedFileIds];
        uploadedFiles.forEach(file => fileIds.push(file.documentId));
        this.uploadedFileIds = fileIds;
    }

    // REQUIREMENT 3 & 4: Robust Form Capture and Save Operation
    saveProperty() {
        if (this.uploadedFileIds.length === 0) {
            this.showToast('Validation Layer Blocked', 'Image upload required.', 'error');
            return;
        }

        const fields = {};
        // Scans both inputs, textareas, and combobox dropdowns cleanly
        this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea').forEach(elem => {
            if (elem.dataset.id) {
                fields[elem.dataset.id] = elem.value;
            }
        });

        const propertyRecord = {
            Name: fields.propName,
            Address__c: fields.address,
            City__c: fields.city,
            State__c: fields.state,
            Postal_Code__c: fields.zip,
            Country__c: fields.country,
            Type__c: fields.type, // Verified picklist mapping parameter
            Furnishing_Status__c: fields.furnishing,
            Status__c: fields.status,
            Rent__c: fields.rent,
            Description__c: fields.desc
        };

        createPropertyWithImage({ propertyRecord: propertyRecord, fileDocumentIds: this.uploadedFileIds })
            .then(() => {
                this.showToast('Success', 'Property record created and geocoded successfully.', 'success');
                this.uploadedFileIds = [];
                this.pageNumber = 1;
                this.loadProperties();
                
                this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea').forEach(elem => {
                    elem.value = '';
                });
            })
            .catch(error => {
                let errorMessage = 'An unexpected database error occurred.';
                if (error && error.body && error.body.message) {
                    errorMessage = error.body.message;
                }
                this.showToast('Database Transaction Denied', errorMessage, 'error');
            });
    }

    handlePrevPage() { if (this.pageNumber > 1) { this.pageNumber--; this.loadProperties(); } }
    handleNextPage() { if (this.pageNumber < this.totalPages) { this.pageNumber++; this.loadProperties(); } }
    get isFirstPage() { return this.pageNumber <= 1; }
    get isLastPage() { return this.pageNumber >= this.totalPages; }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
