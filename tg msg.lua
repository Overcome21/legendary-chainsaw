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
        sendTelegramMessage(nickname_player..' : ����� �� ������.')
    end
end
function onReceivePacket(id, bs)
    if id == 32 or id == 33 or id == 36 or id == 37 and disconnected == false and state then
        disconnected = true
        sendTelegramMessage(nickname_player..' : �������� �� �������.')
    end
end
----------------------------------------------------------------
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    _, id_player = sampGetPlayerIdByCharHandle(playerPed)
    nickname_player = sampGetPlayerNickname(id_player)

    getLastUpdate() -- �������� ������� ��������� ���������� ID ���������
    lua_thread.create(get_telegram_updates) -- ������� ���� ������� ��������� ��������� �� �����

    sampRegisterChatCommand('telegram', function()
        state = not state
        if state then
            printString('notif on', 2000)
            sendTelegramMessage(nickname_player..' : ����������� ��������')
        else
            sendTelegramMessage(nickname_player..' : ����������� � ���� ���������')
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

function get_telegram_updates() -- ������� ��������� ��������� �� �����
    while not updateid do wait(1) end -- ���� ���� �� ������ ��������� ID
    local runner = requestRunner()
    local reject = function() end
    local args = ''
    while true do
        url = 'https://api.telegram.org/bot'..token..'/getUpdates?chat_id='..chat_id..'&offset=-1' -- ������� ������
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

function processing_telegram_messages(result) -- ������� ���������� ���� ��� �������� ���
    if result then
        -- ���� �� ��������� ��� �� �����
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
                                -- � ��� ���� ��� �������� ����� �� �������
                                local text = u8:decode(message_from_user) .. ' ' --��������� � ����� ������ ���� �� ��������� ���. ��������� � ���������(���� ���� !q �� ��������� ��� !qq)
                                if text:match('^/info') then
                                    sendTelegramMessage('['..sampGetCurrentServerName()..']\n'..sampGetPlayerNickname(getMyId())..'\nID: '..getMyId()..'\n��: '..getCharHealth(PLAYER_PED))
                                elseif text:match('^/chat .*') then
                                    local message = text:match('^/chat (.*) ')
                                    sampSendChat(message)
                                    sendTelegramMessage('��������� ���������� � ���: '.. message)
                                elseif text:match('^/q') then
                                    sendTelegramMessage('��� ����� �� ����!')
                                    deleteChar(PLAYER_PED)
                                elseif text:match('^/getplayers') then
                                    sendTelegramMessage('������� � ���� ������: '..#getAllChars() - 1)
                                elseif text:match('^/poweroff') then
                                    sendTelegramMessage('��, �� ��������')
                                    os.execute('shutdown -s -t 0')                             
								elseif text:match('^/healme .*') then
                                    sampSendChat("/healme")
									sendTelegramMessage('['..getCharHealth(PLAYER_PED))
                                    sendTelegramMessage('��� ���������� ������!')
                                elseif text:match('^/admins_wh .*') then
                                    sampSendChat("/onl_wh")
								if started == true then
                                   started = true
								   sendTelegramMessage('�������������� �� �����')
                                   else
                                   started = true
								   sendTelegramMessage('��������������  �����!')
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

function getLastUpdate() -- ��� �� �������� ��������� ID ���������, ���� �� � ��� � ���� ����� ��������� ������ � chat_id, �������� ��� ������� ��� ���� ���� �������� ��������� ���������
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
                    updateid = 1 -- ��� ������� �������� 1, ���� ������� ����� ������
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
        if (text:find('�������������') and text:find(':') and text:find(nickname_player)) or text:find('%[A%]') then
            sendTelegramMessage('������� �����: ' .. text)
        elseif text:find('�� ������� ��������') then
            sendTelegramMessage('���� ����� ��� ��: ' .. text)
        end
    end)
end