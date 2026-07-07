import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

import NAME_FIELD from '@salesforce/schema/Property__c.Name';
import LAT_FIELD from '@salesforce/schema/Property__c.Latitude__c';
import LNG_FIELD from '@salesforce/schema/Property__c.Longitude__c';

const FIELDS = [NAME_FIELD, LAT_FIELD, LNG_FIELD];

export default class PropertyRecordMap extends LightningElement {
    @api recordId;

    mapMarkers = [];
    zoomLevel = 15;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredProperty({ data, error }) {
        if (data) {
            const latitude = data.fields.Latitude__c.value;
            const longitude = data.fields.Longitude__c.value;

            if (latitude && longitude) {
                this.mapMarkers = [
                    {
                        location: {
                            Latitude: latitude,
                            Longitude: longitude
                        },
                        title: data.fields.Name.value
                    }
                ];
            }
        }

        if (error) {
            console.error(error);
        }
    }

    get hasLocation() {
        return this.mapMarkers.length > 0;
    }
}