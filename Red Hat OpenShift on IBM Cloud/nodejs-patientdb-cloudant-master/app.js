var express = require('express'),
    bodyParser = require('body-parser'),
    http = require('http'),
    fs = require('fs');


const util = require('util')

var Cloudant = require('@cloudant/cloudant');
var bootstrapDB = require('./scripts/bootstrapDB.js')

var app = express();
app.set('port', process.env.PORT || 8080);
app.use(bodyParser.json());

var url;
if (process.env.CLOUDANT_URL) {
    url = process.env.CLOUDANT_URL;
} else {
    try {
        url = JSON.parse(fs.readFileSync("./credentials.json", "utf-8")).url;
    } catch(_) {
        throw("Cannot find Cloudant credentials, set CLOUDANT_URL.")
    }
}

Cloudant({ url: url }, function(err, conn) {
    if (err) {
    return console.log('Failed to initialize Cloudant: ' + err.message);
    }
    cloudant = conn;
    console.log("Connected to Cloudant");
    bootstrapDB(url, cloudant).then(result => {
        console.log(result)
    }).then(function(){
        http.createServer(app).listen(app.get('port'), '0.0.0.0', function() {
            console.log('Express server listening on port ' + app.get('port'));
        });
    })
});

app.get('/', function (_, res) {
    // res.send("Node.js API running.")
    cloudant.use('patients').list({include_docs: true}).then ((data) => {
        res.send(data.rows)
    })
});

app.post('/login/user', function(req, res){
    var username = req.body.UID;
    var password = req.body.PASS;

    cloudant.use('patients').find({selector: {user_id: username}}).then((data) => {
        if(data && data.docs && data.docs.length > 0) {
            var patient = data.docs[0]
            var resData = {"ResultSet Output": [{
                "CA_ADDRESS": patient.address,
                "CA_CITY": patient.city,
                "CA_DOB": patient.birthdate,
                "CA_FIRST_NAME": patient.first_name,
                "CA_GENDER": patient.gender,
                "CA_LAST_NAME": patient.last_name,
                "CA_POSTCODE": patient.postcode,
                "CA_USERID": patient.user_id,
                "PATIENTID": patient.patient_id
            }]}
            res.send(resData)
        } else {
            console.error(data)
            res.status(500).send('User "' + username + '" not found')
        }
    }).catch((err) => {
        console.error(err)
        res.status(500).send('User "' + username + '" not found')
    });
})

// ef5335dd-db17-491e-8150-20ce24712b06

app.get('/getInfo/patients/:id', function(req, res) {
    var patientID = req.params.id;
    cloudant.use('patients').find({selector: {patient_id: patientID}}).then((data) => {
        if(data && data.docs && data.docs.length > 0) {
            var patient = data.docs[0]
            var returnCode = 0
            if(data.docs.length == 0) {
                returnCode = 1
            }
            var resData = {"HCCMAREA": {
                "CA_REQUEST_ID": "01IPAT",
                "CA_RETURN_CODE": returnCode,
                "CA_PATIENT_ID": patient.patient_id,
                "CA_PATIENT_REQUEST": {
                    "CA_ADDRESS": patient.address,
                    "CA_CITY": patient.city,
                    "CA_DOB": patient.birthdate,
                    "CA_FIRST_NAME": patient.first_name,
                    "CA_GENDER": patient.gender,
                    "CA_LAST_NAME": patient.last_name,
                    "CA_POSTCODE": patient.postcode,
                    "CA_USERID": patient.user_id,
                    "PATIENTID": patient.patient_id
                }
            }}
            res.send(resData)
        } else {
            console.error(data)
            res.status(500).send('Error getting patient data for ' + patientID)
        }
    }).catch((err) => {
        console.error(err)
        res.status(500).send('Error getting patient data for ' + patientID)
    });    
})

app.get('/getInfo/prescription/:id', function(req, res) {
    var patientID = req.params.id;
    cloudant.use('prescriptions').find({selector: {patient_id: patientID}}).then((data) => {
        if(data && data.docs && data.docs.length > 0) {
            var prescriptions = data.docs
            var prescriptionStr = JSON.stringify(prescriptions)
            prescriptionStr = prescriptionStr.replace(/drug_name/g, "CA_DRUG_NAME")
            prescriptionStr = prescriptionStr.replace(/patient_id/g, "PATIENT")
            prescriptionStr = prescriptionStr.replace(/medication_id/g, "CA_MEDICATION_ID")
            prescriptionStr = prescriptionStr.replace(/reason/g, "REASONDESCRIPTION")
            prescriptions = JSON.parse(prescriptionStr)
            for (var i = 0; i < prescriptions.length; i++) {
                delete prescriptions[i]._id
                delete prescriptions[i]._rev
            }
            var returnCode = 0
            if(data.docs.length == 0) {
                returnCode = 1
            }
            var resData = {"GETMEDO": {
                "CA_REQUEST_ID": "01IPAT",
                "CA_RETURN_CODE": returnCode,
                "CA_PATIENT_ID": patientID,
                "CA_LIST_MEDICATION_REQUEST": {
                    "CA_MEDICATIONS": prescriptions
                }
            }};
            res.send(resData)
        } else {
            console.error(data)
            res.status(500).send('Error getting prescription data for ' + patientID)
        }
    }).catch((err) => {
        console.error(err)
        res.status(500).send('Error getting prescription data for ' + patientID)
    });    
})

// See function getAppointments() for correct way to do this, which maxes out rate limit on Lite plan even with caching
app.get('/appointments/list/:id', function(req,res) {
    var patient = req.params.id;
    cloudant.use('appointments').find({selector: {patient_id: patient}}).then((data) => {
        if(data && data.docs && data.docs.length > 0) {
            var appointments = data.docs;
            var appointmentsData = []
            for (appointment of appointments) {
                appointmentsData.push({
                    "APPT_DATE": appointment.date,
                    "APPT_TIME": appointment.time,
                    "MED_FIELD": "GENERAL PRACTICE",
                })
            }
            var resData = {"ResultSet Output": appointmentsData};
            res.send(resData)
        } else {
            console.error(data)
            res.status(500).send('User "' + username + '" not found')
        }
    }).catch((err) => {
        console.error(err)
        res.status(500).send('User "' + username + '" not found')
    });

})

app.get('/listObs/:id', function(req, res) {
    var patient = req.params.id;
    cloudant.use('observations').find({selector: {patient_id: patient}}).then((data) => {
        if(data && data.docs && data.docs.length > 0) {
            var observations = data.docs;
            var observationsData = []
            for (observation of observations) {
                var toPush = {
                    "CODE": observation.code,
                    "DATEOFOBSERVATION": observation.date,
                    "DESCRIPTION": observation.description,
                    "PATIENT": patient,
                    "UNITS": observation.units,
                    "id": observation.id
                }
                if(observation.numeric_value !== ""){
                    toPush["NUMERICVALUE"]=observation.numeric_value
                }
                if(observation.character_value !== ""){
                    toPush["CHARACTERVALUE"]=observation.character_value
                }
                observationsData.push(toPush)
            }
            var resData = {"ResultSet Output": observationsData};
            res.send(resData)
        } else {
            console.error(data)
            res.status(500).send('User "' + username + '" not found')
        }
    }).catch((err) => {
        console.error(err)
        res.status(500).send('User "' + username + '" not found')
    });
})



// async function getAppointments() {
//     var patientID = "ef5335dd-db17-491e-8150-20ce24712b06"
//     var data = await cloudant.use('appointments').find({selector: {patient_id: patientID}})
//     var patientData = await cloudant.use('patients').find({selector: {patient_id: patientID}})
//     var providerDataCache = {}
//     var locationDataCache = {}

//     if(data && data.docs){
//         var appointments = data.docs;
//         var appointmentsData = []
//         for (appointment of appointments) {
//             if(!providerDataCache.hasOwnProperty(appointment.provider_id)) {
//                 let result = await cloudant.use('providers').find({selector: {organization_id: appointment.provider_id}})
//                 providerDataCache[appointment.provider_id] = result.docs[0]
//             }
//             if(!locationDataCache.hasOwnProperty(appointment.provider_id)) {
//                 let result = await cloudant.use('organizations').find({selector: {organization_id: appointment.provider_id}})
//                 locationDataCache[appointment.provider_id] = result.docs[0]
//             }
//             appointmentsData.push({
//                 "APPT_DATE": appointment.date,
//                 "APPT_TIME": appointment.time,
//                 "DR_NAME": providerDataCache[appointment.provider_id].name,
//                 "FIRSTNAME": patientData.docs[0].first_name,
//                 "LASTNAME": patientData.docs[0].last_name,
//                 "MED_FIELD": providerDataCache[appointment.provider_id].speciality,
//                 "OFF_ADDR": locationDataCache[appointment.provider_id].address,
//                 "OFF_CITY": locationDataCache[appointment.provider_id].city,
//                 "OFF_NAME": locationDataCache[appointment.provider_id].name,
//                 "OFF_STATE": locationDataCache[appointment.provider_id].state,
//                 "OFF_ZIP": locationDataCache[appointment.provider_id].address,
//                 "PATIENTID": patientID
//             })
//         }
//         var resData = {"ResultSet Output": appointmentsData};

//         console.log(resData)
//     }
// }
