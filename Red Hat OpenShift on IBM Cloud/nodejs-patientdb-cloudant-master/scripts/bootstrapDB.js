var path = require('path'),
    fs = require('fs'),
    util = require('util'),
    couchimport = require('couchimport'),
    retry = require('async-await-retry');

const importFile =  util.promisify(couchimport.importFile)

var url;
var cloudant;

module.exports = async function (connectionURL, connectionObj) {
    url = connectionURL;
    cloudant = connectionObj;
    try {
        await retry(importData, ["allergies", 11], {interval: 250});
        await retry(importData, ["appointments", 1791], {interval: 250});
        await retry(importData, ["observations", 7970], {interval: 250});
        await retry(importData, ["organizations", 87], {interval: 250});
        await retry(importData, ["patients", 10], {interval: 250});
        await retry(importData, ["prescriptions", 272], {interval: 250});
        await retry(importData, ["providers", 87], {interval: 250});
    } catch (err) {
        return(err)
    }
    return("Done importing data.");
}

async function importData(database, numEntries) {
    // var opts = {
    //     url: url,
    //     nosql: 'couchdb',
    //     database: database
    // }
    var opts = { delimiter: ",", url: url, database: database };
    try {
        console.log('Creating database "' + database + '"...')
        await cloudant.db.create(database);
    } catch(err) {
        console.log('   -> db exists, skipping')
        return;
    }
    try {
        let result = await importFile('./patient_data/'+ database +'.csv', opts)
        console.log(result)
        if (result.total != numEntries) {
            console.log(result)
            throw("Failed to import all entries for: " + database)
        }
    } catch(err) {
        throw(err)
    }

}