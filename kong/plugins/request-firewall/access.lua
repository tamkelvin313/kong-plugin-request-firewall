local m = {}

function m.fail(msg)
    print(msg)
    return false
end

function m.tableContains(table, value)
    for k, v in pairs(table) do 
        if value == v then return true end 
    end
    return false
end

function m.trim(s)
    if not s then return nil end
    return s:match("^%s*(.-)%s*$")
end

--- check the input is a valid file
-- @params field_attrs object with the following fields ["type", "min", "max", "match", "not_match"], "is_array", "enum", "precision", "positive" are ignored
-- @params name the name of the field we are validating, for logging only
-- @params value the input to be validated
-- @params nested false on the first call, true on nested call
-- @return true if a valid boolean, false if otherwise
function m.isValidFile(field_attrs, name, value, nested)
    local t = type(value)
    if t == "boolean" or t == "string" or t == "number" then
        return m.fail("Invalid file: " .. name)
    end
    if field_attrs.min then
        if not value["size"] or type(value["size"]) ~= "number" or value["size"] < field_attrs.min then
            return m.fail("File size too small: " .. name)
        end
    end
    if field_attrs.max then
        if not value["size"] or type(value["size"]) ~= "number" or value["size"] > field_attrs.max then
            return m.fail("File size too large: " .. name)
        end
    end
    if field_attrs.match then
        if not value["filename"] or type(value["filename"]) ~= "string" or not value["filename"]:match(field_attrs.match) then
            return m.fail("Invalid filename: " .. name)
        end
    end
    if field_attrs.not_match then
        if not value["filename"] or type(value["filename"]) ~= "string" or value["filename"]:match(field_attrs.not_match) then
            return m.fail("Invalid filename: " .. name)
        end
    end
    return true
end

--- check the input is a valid boolean
-- @params field_attrs object with the following fields ["type", "is_array"] "min", "max", "match", "not_match", "enum", "precision", "positive" are ignored
-- @params name the name of the field we are validating, for logging only
-- @params value the input to be validated
-- @params nested false on the first call, true on nested call
-- @return true if a valid boolean, false if otherwise
function m.isValidBoolean(field_attrs, name, value, nested)
    if type(value) == "boolean" then
        if not nested and field_attrs.is_array == 1 then
            return m.fail("Invalid boolean[]: " .. name)
        end
        return true
    elseif type(value) == "string" then
        if not nested and field_attrs.is_array == 1 then
            return m.fail("Invalid boolean[]: " .. name)
        end
        local v = value:lower()
        if v ~= "true" and v ~= "false" and v ~= "0" and v ~= "1" then
            return m.fail("Invalid boolean: " .. name)
        end
        return true
    elseif type(value) == "number" then
        if not nested and field_attrs.is_array == 1 then
            return m.fail("Invalid boolean[]: " .. name)
        end
        if value ~= 0 and value ~= 1 then
            return m.fail("Invalid boolean: " .. name)
        end
        return true
    elseif type(value) == "table" then
        if nested then
            return m.fail("Invalid boolean[]: " .. name)
        elseif field_attrs.is_array == 0 then
            return m.fail("Invalid boolean: " .. name)
        end
        for idx, v in pairs(value) do
            if type(idx) ~= "number" or
                not m.isValidBoolean(field_attrs, name, v, true) then
                return false
            end
        end
        return true
    else
        return m.fail("Invalid boolean: " .. name)
    end
end

--- check the input is a valid string
-- @params field_attrs object with the following fields ["type", "is_array", "min", "max", "match", "not_match", "enum"], "precision", "positive" are ignored
-- @params name the name of the field we are validating, for logging only
-- @params value the input to be validated
-- @params nested false on the first call, true on nested call
-- @return true if a valid string, false if otherwise
function m.isValidString(field_attrs, name, value, nested)
    if type(value) == "string" then
        if not nested and field_attrs.is_array == 1 then
            return m.fail("Invalid string[]: " .. name)
        end
        if field_attrs.min or field_attrs.required then
            local s = m.trim(value)
            local min = 0
            -- min is minimum string length, it won't be negative anyway
            if field_attrs.min then min = field_attrs.min end
            if not s or s:len() < min then
                return m.fail("String too short: " .. name)
            end
        end
        if field_attrs.max and value:len() > field_attrs.max then
            return m.fail("String too long: " .. name)
        end
        if field_attrs.match and not value:match(field_attrs.match) then
            return m.fail("Invalid string content: " .. name)
        end
        if field_attrs.not_match and value:match(field_attrs.not_match) then
            return m.fail("Invalid string content: " .. name)
        end
        if field_attrs.enum and not m.tableContains(field_attrs.enum, value) then
            return m.fail("Invalid string content: " .. name)
        end
        return true
    elseif type(value) == "table" then
        if nested then
            return m.fail("Invalid string[]: " .. name)
        elseif field_attrs.is_array == 0 then
            return m.fail("Invalid string: " .. name)
        end
        for idx, v in pairs(value) do
            if type(idx) ~= "number" or
                not m.isValidString(field_attrs, name, v, true) then
                return false
            end
        end
        return true
    else
        return m.fail("Invalid string: " .. name)
    end
end

--- split a number into integer part and decimal part
-- @params str the input number to be split, has to be a string type
-- @params returnAsNumber if true, return the integer and decimal part as number, otherwise, return as string
-- @return two strings or two numbers (depending on returnAsNumber), nil if not a valid number
-- E.g. splitDecimal("-12.34", false) -> {"-12", "34"}
function m.splitDecimal(str, returnAsNumber)
    if type(str) ~= "string" then str = tostring(str) end
    local startIdx, endIdx = string.find(str, ".", 1, true)
    if nil ~= startIdx then
        local numPart = string.sub(str, 1, endIdx - 1)
        local decPart = string.sub(str, endIdx + 1)
        if nil == string.match(numPart, "^-?%d+$") or nil ==
            string.match(decPart, "^%d+$") then return nil end
        if returnAsNumber then
            return tonumber(numPart), tonumber(decPart)
        else
            return numPart, decPart
        end
    else
        if nil == string.match(str, "^-?%d+$") then return nil end
        if returnAsNumber then
            return tonumber(str)
        else
            return str
        end
    end
end

--- check the input is a valid number, in there a number means a positive non-zero decimal number
-- @params field_attrs object with the following fields ["type", "is_array", "precision", "positive", "min", "max", "enum"], "match" and "not_match" will be ignored
-- @params name the name of the field we are validating, for logging only
-- @params value the input to be validated
-- @params nested false on the first call, true on nested call
-- @return true if a valid number, false if otherwise
function m.isValidNumber(field_attrs, name, value, nested)
    if type(value) == "number" then
        if not nested and field_attrs.is_array == 1 then
            return m.fail("Invalid number[]: " .. name)
        end
        -- if it is already a number, we will ignore the precision checking
        -- if both positive and min are not given, we will assume you want positive number only
        if ((nil == field_attrs.positive and nil == field_attrs.min) or
            field_attrs.positive) and value <= 0 then
            return m.fail("Number is not larger than zero: " .. name)
        end
        if field_attrs.min and field_attrs.min > value then
            return m.fail("Number too small: " .. name)
        end
        if field_attrs.max and field_attrs.max < value then
            return m.fail("Number too large: " .. name)
        end
        -- note, field_attrs.enum is a string array, need to convert value into a string, otherwise tableContains() will never match
        if field_attrs.enum and
            not m.tableContains(field_attrs.enum, tostring(value)) then
            return m.fail("Unexpected number value: " .. name)
        end
        return true
    elseif type(value) == "string" then
        if not nested and field_attrs.is_array == 1 then
            return m.fail("Invalid number[]: " .. name)
        end
        -- value is a string, good :)
        -- we always call splitDecimal, if it is not \d+(.\d+)? , splitDecimal returns nil
        local numPart, decPart = m.splitDecimal(value, false)
        if not numPart then return m.fail("Invalid number: " .. name) end
        if field_attrs.precision and decPart and string.len(decPart) >
            field_attrs.precision then
            return m.fail("Number with invalid precision: " .. name)
        end
        local v2 = tonumber(value)
        -- positive default is true for number type
        -- if both positive and min are not given, we will assume you want positive number only
        if ((nil == field_attrs.positive and nil == field_attrs.min) or
            field_attrs.positive) and v2 <= 0 then
            return m.fail("Number is not larger than zero: " .. name)
        end
        if field_attrs.min and field_attrs.min > v2 then
            return m.fail("Number too small: " .. name)
        end
        if field_attrs.max and field_attrs.max < v2 then
            return m.fail("Number too large: " .. name)
        end
        -- note in there, we call tableContains() with "value" instead of "v2", becaues the enum is string type
        if field_attrs.enum and not m.tableContains(field_attrs.enum, value) then
            return m.fail("Unexpected number value: " .. name)
        end
        return true
    elseif type(value) == "table" then
        if nested then
            return m.fail("Invalid number[]: " .. name)
        elseif field_attrs.is_array == 0 then
            return m.fail("Invalid number: " .. name)
        end
        for idx, v in pairs(value) do
            if type(idx) ~= "number" or
                not m.isValidNumber(field_attrs, name, v, true) then
                return false
            end
        end
        return true
    else
        return m.fail("Invalid number: " .. name)
    end
end

--- validate one single input
-- @params config the config object passed by Kong
-- @params field_attrs object with the following fields ["type", "is_array", "validation"]
-- @params name the name of the input field, for logging purpose only, i.e. for query string parameter "username", it will be "query.username"
-- @params value is the scalar/object we need to validate against the definition
-- @return true if valid, false otherwise
function m.validateField(config, field_attrs, name, value)
    if nil == field_attrs then return m.fail("Unexpected field: " .. name) end

    local type_name = field_attrs.type
    if type_name == "string" then
        return m.isValidString(field_attrs, name, value, false)
    elseif type_name == "number" then
        return m.isValidNumber(field_attrs, name, value, false)
    elseif type_name == "boolean" then
        return m.isValidBoolean(field_attrs, name, value, false)
    elseif type_name == "file" then
        return m.isValidFile(field_attrs, name, value, false)
    else
        -- custom class type
        local custom_classes = config.custom_classes
        if nil == custom_classes then
            return m.fail("custom_classes is undefined. This is config error.")
        end
        local custom_class = custom_classes[type_name]
        if nil == custom_class then
            return m.fail("custom_classes not found: " .. type_name ..
                            ". This is config error.")
        end
        -- TODO we don't really know if nested_value is a table or an array
        if not m.validateTable(config, custom_class, name, value) then
            return false
        end
        return true
    end
end

function m.validateTable(config, schema, table_name, params)
    -- get the params and check against the schema
    for name, value in pairs(params) do
        if nil == schema then
            return m.fail("Unexpected parameters in " .. table_name .. "." .. name)
        end
        local field_attrs = schema[name]
        local b = m.validateField(config, field_attrs, table_name .. "." .. name, value)
        if not b then return false end
    end

    -- loop against the schema and check for required fields
    if nil == schema then return true end
    for name, field_attrs in pairs(schema) do
        local failed = false
        if field_attrs.required == true then
            local value = params[name]
            -- what is the meaning of required?
            -- for boolean, as long as the value exist, that's fine
            -- for string, we have already checked the string is non-empty in isValidString()
            -- for number, a nil value won't be a valid number anyway
            if nil == value then
                -- value does not exist
                failed = true
            end
        end
        if failed then
            return m.fail("Required field not found: " .. table_name .. "." .. name)
        end
    end

    return true
end

return m
