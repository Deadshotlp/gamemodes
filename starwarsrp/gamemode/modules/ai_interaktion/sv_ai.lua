PD.AI = PD.AI or {}

util.AddNetworkString("PD.AI.SendText")
util.AddNetworkString("PD.AI.SendTTS")

local function sendLLMRequest(pEntity, pText)

    print("Send LLM Request")
    -- Use the HTTP library to make a request to the GPT-3 API
    local requestBody = {
        system_instruction = {
            parts = {
                text = "Antworte immer auf Deutsch"
            }
        },
        contents = {
            parts = {
                text = pText
            }
        }
    }

    local function correctFloatToInt(jsonString)
        return string.gsub(jsonString, '(%d+)%.0', '%1')
    end

    HTTP({
        url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=AIzaSyAMmAb8DPxNCoMltDjgBiH9cH-2ppDjIiY",
        type = "application/json",
        method = "post",
        headers = {
            ["Content-Type"] = "application/json"
        },
        body = correctFloatToInt(util.TableToJSON(requestBody)), -- tableToJSON changes integers to float

        success = function(code, body, headers)
            -- Parse the JSON response from the GPT-3 API
            local response = util.JSONToTable(body)

            -- Check if the response contains valid data
            if response["candidates"][1]["content"]["parts"][1]["text"] then

                -- Extract the GPT-3 response content
                local gptResponse = response["candidates"][1]["content"]["parts"][1]["text"]

                -- Print the GPT-3 response to the player's voice chat through tts

                local words = string.Split(gptResponse, " ")

                -- Print the GPT-3 response to the player chat
                net.Start("PD.AI.SendText")
                net.WriteTable(words)
                net.Send(pEntity)

                -- Print the GPT-3 response to the player's voice chat through tts
                net.Start("PD.AI.SendTTS")
                net.WriteTable(words)
                net.WriteEntity(pEntity)
                net.Broadcast()

                -- pEntity:ChatPrint("[AI]: " .. gptResponse)
                -- end
                print(gptResponse)
            else
                -- Print an error message if the response is invalid or contains an error
                -- pEntity:ChatPrint((response and response.error and response.error.message) and "Error! " ..
                --                      response.error.message or "Unknown error! api key is: " .. -- _G.apiKey ..
                -- '') 

                PrintTable(response["candidates"][1]["content"]["parts"][1]["text"])
            end
        end,
        failed = function(err)
            -- Print an error message if the HTTP request fails
            ErrorNoHalt("HTTP Error: " .. err)
        end
    })
end

hook.Add("PlayerSay", "Test", function(sender, text, teamChat)
    local words = string.Split(text, " ")

    if words[1] == "!ai" then
        sendLLMRequest(sender, table.concat(words, " ", 2))
    end
end)
