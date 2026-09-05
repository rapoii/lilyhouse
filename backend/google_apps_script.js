/**
 * Google Apps Script Backend for LilyHouse
 * Free Cloud Persistence & Media Storage for Lilycosrent
 * 
 * Instructions:
 * 1. Open Google Sheets (create a new spreadsheet named 'LilyHouse_Data').
 * 2. Go to Extensions > Apps Script.
 * 3. Replace all code in Code.gs with this script.
 * 4. Click 'Deploy' > 'New deployment'.
 * 5. Select type: 'Web app'.
 * 6. Set Description: 'LilyHouse Sync Endpoint'.
 * 7. Execute as: 'Me'.
 * 8. Who has access: 'Anyone'.
 * 9. Click Deploy and copy the Web App URL into your Flutter app config.
 */

var FOLDER_NAME = 'LilyHouse_Storage';

var TABLES = {
  costumes: 'Costumes',
  accessories: 'Accessories',
  customers: 'Customers',
  rentals: 'Rentals',
  installments: 'Installments',
  installment_logs: 'Installment_Logs'
};

/**
 * Handle GET requests: Health check or fetch all data
 */
function doGet(e) {
  try {
    var action = (e && e.parameter && e.parameter.action) ? e.parameter.action : 'ping';
    
    if (action === 'ping') {
      return jsonResponse({
        status: 'success',
        message: 'LilyHouse Apps Script Backend is online! 🌸'
      });
    }

    if (action === 'fetch_all') {
      return fetchAllData();
    }

    return jsonResponse({
      status: 'error',
      message: 'Unknown GET action: ' + action
    });
  } catch (err) {
    return jsonResponse({
      status: 'error',
      message: err.toString()
    });
  }
}

/**
 * Handle POST requests: Batch sync, media upload, fetch
 */
function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return jsonResponse({
        status: 'error',
        message: 'Empty POST body'
      });
    }

    var data;
    try {
      data = JSON.parse(e.postData.contents);
    } catch (parseErr) {
      return jsonResponse({
        status: 'error',
        message: 'Invalid JSON payload: ' + parseErr.toString()
      });
    }

    var action = data.action;

    if (action === 'sync_batch') {
      return handleSyncBatch(data.items || []);
    } else if (action === 'upload_media') {
      return handleUploadMedia(data);
    } else if (action === 'fetch_all') {
      return fetchAllData();
    } else {
      return jsonResponse({
        status: 'error',
        message: 'Unknown POST action: ' + action
      });
    }
  } catch (err) {
    return jsonResponse({
      status: 'error',
      message: err.toString()
    });
  }
}

/**
 * Process batch of sync operations from Flutter sync queue
 * items: [ { id, table_name, record_id, action: 'insert'|'update'|'delete', payload: {...} } ]
 */
function handleSyncBatch(items) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var processedIds = [];
  var errors = [];

  for (var i = 0; i < items.length; i++) {
    var item = items[i];
    try {
      var tableName = item.table_name;
      var sheetName = TABLES[tableName] || tableName;
      var recordId = item.record_id;
      var op = (item.action || 'insert').toLowerCase();
      var payload = (typeof item.payload === 'string') ? JSON.parse(item.payload) : item.payload;

      var sheet = getOrCreateSheet(ss, sheetName, payload);

      if (op === 'delete') {
        deleteRowById(sheet, recordId);
      } else {
        // insert or update
        upsertRow(sheet, recordId, payload);
      }

      processedIds.push(item.id);
    } catch (opErr) {
      errors.push({
        id: item.id,
        error: opErr.toString()
      });
    }
  }

  return jsonResponse({
    status: errors.length === 0 ? 'success' : 'partial_success',
    processed_ids: processedIds,
    errors: errors
  });
}

/**
 * Upload base64 encoded media to Google Drive folder
 */
function handleUploadMedia(data) {
  var base64Data = data.base64_data;
  var fileName = data.file_name || ('lily_' + new Date().getTime() + '.jpg');
  var mimeType = data.mime_type || 'image/jpeg';

  if (!base64Data) {
    return jsonResponse({
      status: 'error',
      message: 'Missing base64_data in upload_media'
    });
  }

  var folder = getOrCreateFolder(FOLDER_NAME);
  var decodedBytes = Utilities.base64Decode(base64Data);
  var blob = Utilities.newBlob(decodedBytes, mimeType, fileName);
  var file = folder.createFile(blob);
  file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);

  var fileUrl = 'https://drive.google.com/uc?export=view&id=' + file.getId();

  return jsonResponse({
    status: 'success',
    file_id: file.getId(),
    url: fileUrl,
    view_url: file.getUrl()
  });
}

/**
 * Fetch all sheets as a dictionary of table -> row arrays
 */
function fetchAllData() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var result = {};

  for (var tableKey in TABLES) {
    var sheetName = TABLES[tableKey];
    var sheet = ss.getSheetByName(sheetName);
    if (!sheet) {
      result[tableKey] = [];
      continue;
    }

    var data = sheet.getDataRange().getValues();
    if (data.length <= 1) {
      result[tableKey] = [];
      continue;
    }

    var headers = data[0];
    var rows = [];

    for (var r = 1; r < data.length; r++) {
      var rowObj = {};
      for (var c = 0; c < headers.length; c++) {
        rowObj[headers[c]] = data[r][c];
      }
      rows.push(rowObj);
    }

    result[tableKey] = rows;
  }

  return jsonResponse({
    status: 'success',
    data: result
  });
}

/**
 * Helper: Find or create a sheet and ensure headers exist
 */
function getOrCreateSheet(ss, sheetName, samplePayload) {
  var sheet = ss.getSheetByName(sheetName);
  if (!sheet) {
    sheet = ss.insertSheet(sheetName);
    if (samplePayload) {
      var headers = ['id'];
      for (var key in samplePayload) {
        if (key !== 'id' && headers.indexOf(key) === -1) {
          headers.push(key);
        }
      }
      if (headers.indexOf('updated_at') === -1) {
        headers.push('updated_at');
      }
      sheet.appendRow(headers);
      sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold').setBackground('#FFE4EC');
    }
  }
  return sheet;
}

/**
 * Helper: Upsert row by ID
 */
function upsertRow(sheet, recordId, payload) {
  var data = sheet.getDataRange().getValues();
  var headers = data[0] || [];

  if (headers.length === 0) {
    headers = ['id'];
    for (var k in payload) {
      if (k !== 'id') headers.push(k);
    }
    headers.push('updated_at');
    sheet.appendRow(headers);
    data = [headers];
  }

  // Ensure any new payload keys are in headers
  var headerUpdated = false;
  for (var pk in payload) {
    if (headers.indexOf(pk) === -1) {
      headers.push(pk);
      sheet.getRange(1, headers.length).setValue(pk).setFontWeight('bold');
      headerUpdated = true;
    }
  }

  // Find existing row by ID (column 0 is usually id)
  var idCol = headers.indexOf('id');
  if (idCol === -1) idCol = 0;

  var rowIndex = -1;
  for (var r = 1; r < data.length; r++) {
    if (String(data[r][idCol]) === String(recordId)) {
      rowIndex = r + 1; // 1-based index in Sheet
      break;
    }
  }

  var rowValues = [];
  for (var c = 0; c < headers.length; c++) {
    var colName = headers[c];
    if (colName === 'id') {
      rowValues.push(recordId);
    } else if (colName === 'updated_at') {
      rowValues.push(new Date().toISOString());
    } else if (payload.hasOwnProperty(colName)) {
      var val = payload[colName];
      if (typeof val === 'object' && val !== null) {
        rowValues.push(JSON.stringify(val));
      } else {
        rowValues.push(val != null ? val : '');
      }
    } else {
      rowValues.push('');
    }
  }

  if (rowIndex !== -1) {
    sheet.getRange(rowIndex, 1, 1, rowValues.length).setValues([rowValues]);
  } else {
    sheet.appendRow(rowValues);
  }
}

/**
 * Helper: Delete row by ID
 */
function deleteRowById(sheet, recordId) {
  var data = sheet.getDataRange().getValues();
  if (data.length <= 1) return;

  var headers = data[0];
  var idCol = headers.indexOf('id');
  if (idCol === -1) idCol = 0;

  for (var r = data.length - 1; r >= 1; r--) {
    if (String(data[r][idCol]) === String(recordId)) {
      sheet.deleteRow(r + 1);
      return;
    }
  }
}

/**
 * Helper: Get or create Google Drive folder
 */
function getOrCreateFolder(folderName) {
  var folders = DriveApp.getFoldersByName(folderName);
  if (folders.hasNext()) {
    return folders.next();
  }
  return DriveApp.createFolder(folderName);
}

/**
 * Helper: Format JSON Output
 */
function jsonResponse(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
