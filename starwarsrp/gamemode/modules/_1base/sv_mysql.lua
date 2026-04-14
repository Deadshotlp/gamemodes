PD.SQL = {}
PD.SQL.Config = {
    Host = "45.62.160.95",
    Username = "u15381_JNwvtifGyL",
    Password = "fMebB^YO+sxa6@R.Gz+WM36i",
    Database = "s15381_test",
    Port = 3306,
	MySQL = true,
	MaxQueryRetries = 3,
	ReconnectBaseDelay = 2,
	ReconnectMaxDelay = 30
}
PD.SQL.Connected = false

local traceback = debug.traceback

local _mysqloo, database = nil, nil
local reconnectAttempts = 0
local reconnectTimerName = "PD.SQL.Reconnect"
local queuedQueries = {}
local activeTransaction = nil
local globalErrorHandler = nil

local SQL = PD.SQL

function SQL.Print(err, trace)
	print("[PD.SQL] " .. tostring(err))
	if trace and trace ~= "" then
		print(trace)
	end
end

local function Error(err, trace)
	SQL.Print(err, trace or traceback("", 2))
end

local function EmitDatabaseError(kind, message, context, trace)
	if isfunction(globalErrorHandler) then
		local ok, handlerErr = pcall(globalErrorHandler, kind, message, context or {}, trace)
		if not ok then
			Error("Global DB error handler failed: " .. tostring(handlerErr), traceback("", 2))
		end
	end

	hook.Call("PD.Gamemode.DatabaseError", nil, kind, message, context or {}, trace)
end

local function defaultOnConnected()
	PD.SQL.Connected = true
	hook.Call("PD.Gamemode.DatabaseConnected")
end

local function defaultOnConnectionFailed(error_text)
	Error("Failed to connect to the server: " .. error_text)
	EmitDatabaseError("connection_failed", tostring(error_text), {
		configHost = PD.SQL.Config.Host,
		configDatabase = PD.SQL.Config.Database
	})
	hook.Call("PD.Gamemode.DatabaseConnectionFailed", nil, error_text)
end

local function quoteIdentifier(identifier)
	identifier = tostring(identifier or "")
	identifier = identifier:gsub("`", "``")
	return "`" .. identifier .. "`"
end

local function toSQLValue(value)
	local valueType = type(value)

	if value == nil then
		return "NULL"
	end

	if valueType == "boolean" then
		return value and "1" or "0"
	end

	if valueType == "number" then
		if value ~= value then
			return "NULL"
		end

		return tostring(value)
	end

	return SQL.EscapeString(tostring(value))
end

local function buildAllowedMap(allowedFields)
	if not istable(allowedFields) then
		return nil
	end

	local map = {}
	for i = 1, #allowedFields do
		map[tostring(allowedFields[i])] = true
	end

	return map
end

local function isFieldAllowed(fieldName, allowedMap)
	if not allowedMap then
		return true
	end

	return allowedMap[tostring(fieldName)] == true
end

local function buildWhereFromTable(whereData, allowedFields)
	if not istable(whereData) then
		return nil, "BuildWhere expected table data"
	end

	local allowedMap = buildAllowedMap(allowedFields)
	local clauses = {}

	for key, value in pairs(whereData) do
		if isFieldAllowed(key, allowedMap) then
			if value == nil then
				table.insert(clauses, quoteIdentifier(key) .. " IS NULL")
			elseif istable(value) then
				local inValues = {}
				for i = 1, #value do
					table.insert(inValues, toSQLValue(value[i]))
				end

				if #inValues == 0 then
					return nil, "BuildWhere received empty IN-list for field '" .. tostring(key) .. "'"
				end

				table.insert(clauses, quoteIdentifier(key) .. " IN (" .. table.concat(inValues, ", ") .. ")")
			else
				table.insert(clauses, quoteIdentifier(key) .. " = " .. toSQLValue(value))
			end
		end
	end

	if #clauses == 0 then
		return nil, "BuildWhere has no allowed fields"
	end

	return table.concat(clauses, " AND ")
end

local function flushQueue()
	if #queuedQueries == 0 then
		return
	end

	local toRun = queuedQueries
	queuedQueries = {}

	for i = 1, #toRun do
		local entry = toRun[i]
		if entry and entry.query then
			SQL.Query(entry.query, entry.callback, entry.firstRow, entry.callbackObj, entry.retryCount)
		end
	end
end

local function scheduleReconnect(reason)
	if timer.Exists(reconnectTimerName) then
		return
	end

	reconnectAttempts = reconnectAttempts + 1
	local base = tonumber(PD.SQL.Config.ReconnectBaseDelay) or 2
	local maxDelay = tonumber(PD.SQL.Config.ReconnectMaxDelay) or 30
	local delay = math.min(maxDelay, base * math.max(1, reconnectAttempts))

	Error("Database reconnect scheduled in " .. delay .. "s. Reason: " .. tostring(reason), traceback("", 2))

	timer.Create(reconnectTimerName, delay, 1, function()
		SQL.Connect()
	end)
end

local function ensureMySQLoo()
	if _mysqloo then
		return true
	end

	local ok, err = pcall(require, "mysqloo")
	if not ok or not mysqloo then
		Error("mysqloo module doesn't exist, get it from https://github.com/FredyH/MySQLOO; details: " .. tostring(err))
		return false
	end

	_mysqloo = mysqloo
	return true
end

local function statusIsConnected()
	return database and _mysqloo and database:status() == _mysqloo.DATABASE_CONNECTED
end

local function canRetryOnError(errorText)
	if not database or not _mysqloo then
		return false
	end

	local status = database:status()
	if status == _mysqloo.DATABASE_NOT_CONNECTED or status == _mysqloo.DATABASE_CONNECTING then
		return true
	end

	return tostring(errorText):find("Lost connection to MySQL server during query", 1, true) ~= nil
end

function SQL.Connect(onConnected, onConnectionFailed)
	onConnected = onConnected or defaultOnConnected
	onConnectionFailed = onConnectionFailed or defaultOnConnectionFailed

	if not PD.SQL.Config.MySQL then
		Error("MySQL is disabled in PD.SQL.Config.MySQL")
		return false
	end

	if not ensureMySQLoo() then
		return false
	end

	if database then
		local status = database:status()
		if status == _mysqloo.DATABASE_CONNECTING or status == _mysqloo.DATABASE_CONNECTED then
			return true
		end
	end

	PD.SQL.Connected = false

	database = _mysqloo.connect(
		PD.SQL.Config.Host,
		PD.SQL.Config.Username,
		PD.SQL.Config.Password,
		PD.SQL.Config.Database,
		PD.SQL.Config.Port
	)

	function database.onConnected()
		reconnectAttempts = 0
		if timer.Exists(reconnectTimerName) then
			timer.Remove(reconnectTimerName)
		end

		onConnected()
		flushQueue()
	end

	function database.onConnectionFailed(_, error_text)
		onConnectionFailed(error_text)
		scheduleReconnect(error_text)
	end

	database:connect()

	return true
end

function SQL.Begin()
	if not statusIsConnected() then
		Error("Cannot begin transaction while not connected")
		SQL.Connect()
		return nil
	end

	if activeTransaction then
		Error("A transaction is already active")
		return nil
	end

	activeTransaction = database:createTransaction()

	return function(queryString)
		if not activeTransaction then
			Error("Transaction no longer active")
			return nil
		end

		local q = database:query(queryString)
		activeTransaction:addQuery(q)
		return q
	end
end

function SQL.Commit(callback, onError)
	if not activeTransaction then
		Error("No active transaction to commit")
		return false
	end

	local tx = activeTransaction
	activeTransaction = nil

	tx.SQL_traceback = traceback("", 2)

	tx.onSuccess = function(...)
		if callback then
			callback(...)
		end
	end

	tx.onError = function(_, error_text)
		if onError then
			onError(error_text)
			return
		end

		EmitDatabaseError("transaction_error", tostring(error_text), {
			trace = tx.SQL_traceback
		}, tx.SQL_traceback)
		Error("Transaction error: " .. tostring(error_text), tx.SQL_traceback)
	end

	tx:start()

	return true
end
function SQL.Query(queryString, callback, firstRow, callbackObj, retryCount)
	retryCount = retryCount or 0

	if not ensureMySQLoo() then
		return nil
	end

	if not statusIsConnected() then
		table.insert(queuedQueries, {
			query = queryString,
			callback = callback,
			firstRow = firstRow,
			callbackObj = callbackObj,
			retryCount = retryCount
		})

		SQL.Connect()
		return nil
	end

	local query = database:query(queryString)
	query.SQL_query_string = queryString
	query.SQL_callback = callback
	query.SQL_first_row = firstRow
	query.SQL_callback_obj = callbackObj
	query.SQL_retry_count = retryCount
	query.SQL_traceback = traceback("", 2)

	query.onSuccess = function(q, data)
		if q.SQL_callback then
			if q.SQL_first_row then
				data = data and data[1] or nil
			end

			q.SQL_callback(data, q.SQL_callback_obj)
		end
	end

	query.onError = function(q, error_text)
		if canRetryOnError(error_text) and q.SQL_retry_count < (tonumber(PD.SQL.Config.MaxQueryRetries) or 3) then
			PD.SQL.Connected = false
			table.insert(queuedQueries, {
				query = q.SQL_query_string,
				callback = q.SQL_callback,
				firstRow = q.SQL_first_row,
				callbackObj = q.SQL_callback_obj,
				retryCount = q.SQL_retry_count + 1
			})

			scheduleReconnect(error_text)
			return
		end

		EmitDatabaseError("query_error", tostring(error_text), {
			query = q.SQL_query_string,
			retries = q.SQL_retry_count
		}, q.SQL_traceback)
		Error("Query error: " .. tostring(error_text), q.SQL_traceback)
	end

	query:start()

	return query
end

function SQL.EscapeString(value, no_quotes)
	value = tostring(value or "")

	local escaped
	if database and statusIsConnected() then
		escaped = database:escape(value)
	else
		escaped = value
		escaped = escaped:gsub("\\", "\\\\")
		escaped = escaped:gsub("\0", "\\0")
		escaped = escaped:gsub("\n", "\\n")
		escaped = escaped:gsub("\r", "\\r")
		escaped = escaped:gsub("\026", "\\Z")
		escaped = escaped:gsub("'", "\\'")
		escaped = escaped:gsub('"', '\\"')
	end

	if no_quotes then
		return escaped
	else
		return "'" .. escaped .. "'"
	end
end

function SQL.FetchAll(queryString, callback, callbackObj)
	return SQL.Query(queryString, callback, false, callbackObj)
end

function SQL.FetchOne(queryString, callback, callbackObj)
	return SQL.Query(queryString, callback, true, callbackObj)
end

function SQL.Execute(queryString, callback, callbackObj)
	return SQL.Query(queryString, callback, false, callbackObj)
end

function SQL.SetErrorHandler(handler)
	if handler ~= nil and not isfunction(handler) then
		Error("SQL.SetErrorHandler expected function or nil")
		return false
	end

	globalErrorHandler = handler
	return true
end

function SQL.BuildInsert(tableName, data, allowedFields)
	if not istable(data) then
		return nil, "BuildInsert expected table data"
	end

	local allowedMap = buildAllowedMap(allowedFields)
	local columns, values = {}, {}

	for key, value in pairs(data) do
		if isFieldAllowed(key, allowedMap) then
			table.insert(columns, quoteIdentifier(key))
			table.insert(values, toSQLValue(value))
		end
	end

	if #columns == 0 then
		return nil, "BuildInsert has no allowed fields"
	end

	return "INSERT INTO " .. quoteIdentifier(tableName) .. " (" .. table.concat(columns, ", ") .. ") VALUES (" .. table.concat(values, ", ") .. ")"
end

function SQL.BuildUpdate(tableName, data, whereClause, allowedFields, allowedWhereFields)
	if not istable(data) then
		return nil, "BuildUpdate expected table data"
	end

	local allowedMap = buildAllowedMap(allowedFields)
	local sets = {}

	for key, value in pairs(data) do
		if isFieldAllowed(key, allowedMap) then
			table.insert(sets, quoteIdentifier(key) .. " = " .. toSQLValue(value))
		end
	end

	if #sets == 0 then
		return nil, "BuildUpdate has no allowed fields"
	end

	if whereClause == nil or whereClause == "" then
		return nil, "BuildUpdate requires whereClause"
	end

	if istable(whereClause) then
		local builtWhere, whereErr = SQL.BuildWhere(whereClause, allowedWhereFields)
		if not builtWhere then
			return nil, whereErr or "BuildUpdate could not build whereClause"
		end

		whereClause = builtWhere
	end

	return "UPDATE " .. quoteIdentifier(tableName) .. " SET " .. table.concat(sets, ", ") .. " WHERE " .. tostring(whereClause)
end

function SQL.BuildWhere(whereData, allowedFields)
	return buildWhereFromTable(whereData, allowedFields)
end

function SQL.Insert(tableName, data, allowedFields, callback, callbackObj)
	local queryString, err = SQL.BuildInsert(tableName, data, allowedFields)
	if not queryString then
		EmitDatabaseError("build_insert_error", err or "Unknown insert build error", {
			tableName = tableName
		})
		Error("BuildInsert error: " .. tostring(err), traceback("", 2))
		return nil
	end

	return SQL.Execute(queryString, callback, callbackObj)
end

function SQL.Update(tableName, data, whereClause, allowedFields, callback, callbackObj, allowedWhereFields)
	if istable(whereClause) then
		local builtWhere, whereErr = SQL.BuildWhere(whereClause, allowedWhereFields)
		if not builtWhere then
			EmitDatabaseError("build_update_error", whereErr or "Invalid where table", {
				tableName = tableName
			})
			Error("BuildWhere error: " .. tostring(whereErr), traceback("", 2))
			return nil
		end

		whereClause = builtWhere
	end

	local queryString, err = SQL.BuildUpdate(tableName, data, whereClause, allowedFields, allowedWhereFields)
	if not queryString then
		EmitDatabaseError("build_update_error", err or "Unknown update build error", {
			tableName = tableName,
			where = tostring(whereClause)
		})
		Error("BuildUpdate error: " .. tostring(err), traceback("", 2))
		return nil
	end

	return SQL.Execute(queryString, callback, callbackObj)
end

function SQL.GetDatabase()
	return database
end

function SQL.IsConnected()
	return statusIsConnected()
end

function SQL.TableExistsQuery(name)
	return "SHOW TABLES LIKE " .. SQL.EscapeString(name)
end

return SQL