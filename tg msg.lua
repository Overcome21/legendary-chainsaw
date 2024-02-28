local chat_id = '929877709'
local token = '6794206557:AAFl37WdG4AlKGKAMKcTB-DmvHib1q14NK8'
----------------------------------------------------------------
require 'lib.moonloader'
require 'lib.sampfuncs'
requests = require 'requests'
encoding = require("encoding");
encoding.default = 'CP1251';
u8 = encoding.UTF8

local effil = require 'effil'
----------------------------------------------------------------
function onSendRpc(id, bitStream, priority, reliability, orderingChannel, shiftTs)
    if id == 25 and disconnected and state then
        disconnected = false
        sendTelegramMessage(nickname_player..' : Зашел на сервер.')
    end
end
function onReceivePacket(id, bs)
    if id == 32 or id == 33 or id == 36 or id == 37 and disconnected == false and state then
        disconnected = true
        sendTelegramMessage(nickname_player..' : Отключен от сервера.')
    end
end
----------------------------------------------------------------
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    _, id_player = sampGetPlayerIdByCharHandle(playerPed)
    nickname_player = sampGetPlayerNickname(id_player)

    getLastUpdate() -- вызываем функцию получения последнего ID сообщения
    lua_thread.create(get_telegram_updates) -- создаем нашу функцию получения сообщений от юзера

    sampRegisterChatCommand('telegram', function()
        state = not state
        if state then
            printString('notif on', 2000)
            sendTelegramMessage(nickname_player..' : Уведомления включены')
        else
            sendTelegramMessage(nickname_player..' : Уведомления о боте отключены')
            printString('notif off', 2000)
        end
    end)

    while true do wait(0)
        --
    end
end

function requestRunner()
    return effil.thread(function(u, a)
        local https = require 'ssl.https'
        local ok, result = pcall(https.request, u, a)
        if ok then
            return {true, result}
        else
            return {false, result}
        end
    end)
end

function async_http_request(url, args, resolve, reject)
    local runner = requestRunner()
    if not reject then reject = function() end end
    lua_thread.create(function()
        threadHandle(runner, url, args, resolve, reject)
    end)
end

function get_telegram_updates() -- функция получения сообщений от юзера
    while not updateid do wait(1) end -- ждем пока не узнаем последний ID
    local runner = requestRunner()
    local reject = function() end
    local args = ''
    while true do
        url = 'https://api.telegram.org/bot'..token..'/getUpdates?chat_id='..chat_id..'&offset=-1' -- создаем ссылку
        threadHandle(runner, url, args, processing_telegram_messages, reject)
        wait(0)
    end
end

function threadHandle(runner, url, args, resolve, reject)
    local t = runner(url, args)
    local r = t:get(0)
    while not r do
        r = t:get(0)
        wait(0)
    end
    local status = t:status()
    if status == 'completed' then
        local ok, result = r[1], r[2]
        if ok then resolve(result) else reject(result) end
    elseif err then
        reject(err)
    elseif status == 'canceled' then
        reject(status)
    end
    t:cancel(0)
end

function getMyId()
    return select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
end

function processing_telegram_messages(result) -- функция проверОчки того что отправил чел
    if result then
        -- тута мы проверяем все ли верно
        local proc_table = decodeJson(result)
        if proc_table.ok then
            if #proc_table.result > 0 then
                local res_table = proc_table.result[1]
                if res_table then
                    if res_table.update_id ~= updateid then
                        updateid = res_table.update_id
                        local message_from_user = res_table.message.text
                        if message_from_user then
                            if res_table.message.chat.id then
                                -- и тут если чел отправил текст мы сверяем
                                local text = u8:decode(message_from_user) .. ' ' --добавляем в конец пробел дабы не произошли тех. шоколадки с командами(типо чтоб !q не считалось как !qq)
                                if text:match('^/info') then
                                    sendTelegramMessage('['..sampGetCurrentServerName()..']\n'..sampGetPlayerNickname(getMyId())..'\nID: '..getMyId()..'\nХП: '..getCharHealth(PLAYER_PED))
                                elseif text:match('^/chat .*') then
                                    local message = text:match('^/chat (.*) ')
                                    sampSendChat(message)
                                    sendTelegramMessage('Сообщение отправлено в чат: '.. message)
                                elseif text:match('^/q') then
                                    sendTelegramMessage('Бот вышел из игры!')
                                    deleteChar(PLAYER_PED)
                                elseif text:match('^/getplayers') then
                                    sendTelegramMessage('Игроков в зоне стрима: '..#getAllChars() - 1)
                                elseif text:match('^/poweroff') then
                                    sendTelegramMessage('ок, пк выключен')
                                    os.execute('shutdown -s -t 0')                             
								elseif text:match('^/healme .*') then
                                    sampSendChat("/healme")
									sendTelegramMessage('['..getCharHealth(PLAYER_PED))
                                    sendTelegramMessage('Бот исползовал аптеку!')
                                elseif text:match('^/admins_wh .*') then
                                    sampSendChat("/onl_wh")
								if started == true then
                                   started = true
								   sendTelegramMessage('Администраторы не Видны')
                                   else
                                   started = true
								   sendTelegramMessage('Администраторы  Видны!')
                                   end
								
                                   
								   
								elseif text:match('^/help .*') then
                                    sendTelegramMessage('/info\n/chat\n/q\n/getplayers\n/poweroff\n/healme\n/time\n/admins_wh')
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function getLastUpdate() -- тут мы получаем последний ID сообщения, если же у вас в коде будет настройка токена и chat_id, вызовите эту функцию для того чтоб получить последнее сообщение
    async_http_request('https://api.telegram.org/bot'..token..'/getUpdates?chat_id='..chat_id..'&offset=-1','',function(result)
        if result then
            local proc_table = decodeJson(result)
            if proc_table.ok then
                if #proc_table.result > 0 then
                    local res_table = proc_table.result[1]
                    if res_table then
                        updateid = res_table.update_id
                    end
                else
                    updateid = 1 -- тут зададим значение 1, если таблица будет пустая
                end
            end
        end
    end)
end

function sendTelegramMessage(text)
    text = string.format('%s[%s]', nickname_player, id_player) .. os.date(' %H:%M:%S\n') .. text
    text = text:gsub('{......}', '');
    text = text:gsub(' ', '%+');
    text = text:gsub('\n', '%%0A');
    text = u8:encode(text, 'CP1251')
    local URL = 'https://api.telegram.org/bot' .. token .. '/sendMessage?chat_id=' .. chat_id .. '&text=' .. text
    requests.get(URL)
end

require('samp.events').onServerMessage = function(color, text)
    lua_thread.create(function()
        if (text:find('Администратор') and text:find(':') and text:find(nickname_player)) or text:find('%[A%]') then
            sendTelegramMessage('Написал админ: ' .. text)
        elseif text:find('Вы успешно получили') then
            sendTelegramMessage('Тебе упало что то: ' .. text)
        end
    end)
end