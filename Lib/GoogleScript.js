// Код для Google Apps Script (Развернуть как веб-приложение)
// См. инструкцию в walkthrough.md

function doGet(e) {
  var key = e.parameter.key;
  var hwid = e.parameter.hwid;
  
  if (!key || !hwid) {
    return ContentService.createTextOutput("ERROR: Missing parameters");
  }
  
  // Получаем активный лист таблицы
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  var data = sheet.getDataRange().getValues();
  
  // Ищем строку с введенным ключом в колонке A
  var keyRow = -1;
  for (var i = 0; i < data.length; i++) {
    if (data[i][0].toString().trim() === key.trim()) {
      keyRow = i + 1; // Номер строки (1-based)
      break;
    }
  }
  
  // Если ключ не найден в таблице
  if (keyRow === -1) {
    return ContentService.createTextOutput("ERROR: Invalid key");
  }
  
  // Читаем уже зарегистрированный HWID из колонки B
  var registeredHwid = data[keyRow - 1][1] ? data[keyRow - 1][1].toString().trim() : "";
  
  if (registeredHwid === "") {
    // Ключ еще не использовался -> привязываем к текущему HWID
    sheet.getRange(keyRow, 2).setValue(hwid);
    sheet.getRange(keyRow, 3).setValue(new Date()); // Записываем дату активации
    return ContentService.createTextOutput("SUCCESS: Activated");
  } else if (registeredHwid.toLowerCase() === hwid.toLowerCase()) {
    // Повторный запуск на том же компьютере
    return ContentService.createTextOutput("SUCCESS: Already activated");
  } else {
    // Ключ привязан к другому устройству
    return ContentService.createTextOutput("ERROR: Key already in use on another device");
  }
}
