--****************************************************************************************
--
-- ====================================================================
-- Corona Cloud low-level layer LUA Library
-- ====================================================================
--
-- File: corona-cloud-core.lua
--
-- Copyright © 2013 Corona Labs Inc. All Rights Reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- * Redistributions of source code must retain the above copyright
-- notice, this list of conditions and the following disclaimer.
-- * Redistributions in binary form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
-- * Neither the name of the company nor the names of its contributors
-- may be used to endorse or promote products derived from this software
-- without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL CORONA LABS INC. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
--****************************************************************************************

local coronaCloudController = {}

-------------------------------------------------
-- HELPERS
-------------------------------------------------

coronaCloudController.CC_URL = "api.coronalabs.com"
coronaCloudController.CC_ACCESS_KEY = ""
coronaCloudController.CC_SECRET_KEY = ""
coronaCloudController.authToken = ""

-- public debug variable
coronaCloudController.debugEnabled = false

-- public variable, prefix for all the print output if debug is enabled
coronaCloudController.debugTextPrefix = "Corona Cloud: "

-------------------------------------------------
-- IMPORTS
-------------------------------------------------

local json = require("json")

-------------------------------------------------
-- PRIVATE METHODS
-------------------------------------------------

-- url encode
local function _urlencode( str )
	if str then
		str = string.gsub ( str, "\n", "\r\n" )
		str = string.gsub ( str, "([^%w ])",
		function ( c ) return string.format ( "%%%02X", string.byte( c ) ) end )
		str = string.gsub ( str, " ", "+" )
	end
	return str
end

-- b64 encoding
local function _b64enc( data )
    -- character table string
	local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

    return ( (data:gsub( '.', function( x ) 
        local r,b='', x:byte()
        for i=8,1,-1 do r=r .. ( b % 2 ^ i - b % 2 ^ ( i - 1 ) > 0 and '1' or '0' ) end
        return r;
    end ) ..'0000' ):gsub( '%d%d%d?%d?%d?%d?', function( x )
        if ( #x < 6 ) then return '' end
        local c = 0
        for i = 1, 6 do c = c + ( x:sub( i, i ) == '1' and 2 ^ ( 6 - i ) or 0 ) end
        return b:sub( c+1, c+1 )
    end) .. ( { '', '==', '=' } )[ #data %3 + 1] )
end

-- b64 decoding
local function _b64dec( data )
	-- character table string
	local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

    data = string.gsub( data, '[^'..b..'=]', '' )
    return ( data:gsub( '.', function( x )
        if ( x == '=' ) then return '' end
        local r,f = '', ( b:find( x ) - 1 )
        for i = 6, 1, -1 do r = r .. ( f % 2 ^ i - f % 2 ^ ( i - 1 ) > 0 and '1' or '0' ) end
        return r;
    end ):gsub( '%d%d%d?%d?%d?%d?%d?%d?', function( x )
        if ( #x ~= 8 ) then return '' end
        local c = 0
        for i = 1, 8 do c = c + ( x:sub( i, i ) == '1' and 2 ^ ( 8 - i ) or 0 ) end
        return string.char( c )
    end ))
end

local function _createBasicAuthHeader( username, password )
	-- the header format is "Basic <base64 encoded username:password>"
	local header = "Basic "
	local authDetails = _b64enc( username .. ":" .. password )
	header = header .. authDetails
	return header
end

local function _postCC( path, parameters, networkListener )
	-- POST call to CC
	if not parameters then
		parameters = ""
	end

	local params = {}

	params.body = parameters

	local authHeader = _createBasicAuthHeader( coronaCloudController.CC_ACCESS_KEY, coronaCloudController.CC_SECRET_KEY )

	local headers = {}
	headers[ "Authorization" ] = authHeader
	params.headers = headers

	local url = "https://" .. coronaCloudController.CC_URL

	if coronaCloudController.debugEnabled then
		print( coronaCloudController.debugTextPrefix .. "\n----------------" )
		print( coronaCloudController.debugTextPrefix .. "-- POST Call ---" )
		print( coronaCloudController.debugTextPrefix .. "Post URL: "..url )
		print( coronaCloudController.debugTextPrefix .. "Post Path: "..path )
		print( coronaCloudController.debugTextPrefix .. "Post Parameters: "..parameters )
		print( coronaCloudController.debugTextPrefix .. "----------------" )
	end

	local hReq = url .. "/" .. path
	
	if coronaCloudController.debugEnabled then
		print( coronaCloudController.debugTextPrefix .. "\nPost Request: " .. hReq )
	end
	
	network.request( hReq, "POST", networkListener, params )
end

local function _getCC( path, parameters, networkListener )
	-- GET call to CC
	local params = {}

	--params.body = parameters

	local authHeader = _createBasicAuthHeader( coronaCloudController.CC_ACCESS_KEY, coronaCloudController.CC_SECRET_KEY )

	local headers = {}
	headers[ "Authorization" ] = authHeader

	params.headers = headers

	local url = "https://" .. coronaCloudController.CC_URL

	if coronaCloudController.debugEnabled then
		print( coronaCloudController.debugTextPrefix .. "\n----------------" )
		print( coronaCloudController.debugTextPrefix .. "-- GET Call ---" )
		print( coronaCloudController.debugTextPrefix .. "Get URL: "..url )
		print( coronaCloudController.debugTextPrefix .. "Get Path: "..path )
		print( coronaCloudController.debugTextPrefix .. "Get Parameters: "..parameters )
		print( coronaCloudController.debugTextPrefix .. "----------------" )
	end

	local hReq = url .. "/" .. path .. "?" .. parameters

	if coronaCloudController.debugEnabled then
		print( coronaCloudController.debugTextPrefix .. "\nGet Request: " .. hReq )
	end
	
	network.request( hReq, "GET", networkListener, params )
end

local function _putCC( path, parameters, networkListener )
	-- PUT call to Corona Cloud

	local params = {}

	local authHeader = _createBasicAuthHeader( coronaCloudController.CC_ACCESS_KEY, coronaCloudController.CC_SECRET_KEY )

	local headers = {}
	headers[ "Authorization" ] = authHeader

	params.headers = headers
	params.body = putData

	local url = "https://" .. coronaCloudController.CC_URL

	if coronaCloudController.debugEnabled then
		print( coronaCloudController.debugTextPrefix .. "\n----------------" )
		print( coronaCloudController.debugTextPrefix .. "-- PUT Call ---" )
		print( coronaCloudController.debugTextPrefix .. "Put URL: "..url )
		print( coronaCloudController.debugTextPrefix .. "Put Path: " .. path )
		print( coronaCloudController.debugTextPrefix .. "Put Parameters: " .. parameters )
		print( coronaCloudController.debugTextPrefix .. "----------------")
	end
	
	local hReq = url.."/"..path.."?"..parameters

	if coronaCloudController.debugEnabled then
		print(coronaCloudController.debugTextPrefix .. "\nPut Request: "..hReq)
	end
	
	network.request(hReq, "PUT", networkListener, params)
end

local function _deleteCC(path, parameters, networkListener)
	-- Delete call to Corona Cloud

	local params = {}


	local authHeader = _createBasicAuthHeader(coronaCloudController.CC_ACCESS_KEY, coronaCloudController.CC_SECRET_KEY)

	local headers = {}
	headers["Authorization"] = authHeader

	params.headers = headers

	local url = "https://"..coronaCloudController.CC_URL

	if coronaCloudController.debugEnabled then
		print(coronaCloudController.debugTextPrefix .. "\n----------------")
		print(coronaCloudController.debugTextPrefix .. "-- DELETE Call ---")
		print(coronaCloudController.debugTextPrefix .. "Delete URL: "..url)
		print(coronaCloudController.debugTextPrefix .. "Delete Path: "..path)
		print(coronaCloudController.debugTextPrefix .. "Delete Parameters: "..parameters)
		print(coronaCloudController.debugTextPrefix .. "----------------")
	end

	local hReq = url.."/"..path.."?"..parameters

	if coronaCloudController.debugEnabled then
		print(coronaCloudController.debugTextPrefix .. "\nDelete Request: "..hReq)
	end
	
	network.request(hReq, "DELETE", networkListener, params)
end


-------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------

function coronaCloudController.init(accessKey, secretKey)	-- constructor
	-- initialize the Corona Cloud connection
	coronaCloudController.CC_ACCESS_KEY = accessKey
	coronaCloudController.CC_SECRET_KEY = secretKey
end

-------------------------------------------------
-- User
-------------------------------------------------

function coronaCloudController.loginWeb()
	local authToken

	return authToken
end

-------------------------------------------------

function coronaCloudController.loginAPI(username, password, delegate)
	local params = "login="..username.."&password="..password

	local path = "user_sessions/user_login.json"

	-- set AuthToken when it gets it
	local function networkListener(event)
		local response = json.decode(event.response)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else

			if (response.auth_token) then
				coronaCloudController.authToken = response.auth_token
				if coronaCloudController.debugEnabled then
					print(coronaCloudController.debugTextPrefix .. "User Logged In!")
					print(coronaCloudController.debugTextPrefix .. "Auth Token: "..coronaCloudController.authToken)
					
					if delegate then
						coronaCloudController.getMyProfile( delegate )
						delegate.logUserIn()
					end
					
				end
				Runtime:dispatchEvent({name="LoggedIn"})
				return true
			else
				if coronaCloudController.debugEnabled then
					print(coronaCloudController.debugTextPrefix .. "Login Error: "..event.response)
				end
				Runtime:dispatchEvent({name="LoginError", errorMsg=response.errors[1]})
				
			end
		end
	end

	_postCC(path, params, networkListener)

	return true
end

-------------------------------------------------

function coronaCloudController.loginFacebook(facebookID, accessToken, delegate)
	local params = "facebook_id="..facebookID.."&access_token="..accessToken

	local path = "facebook_login.json"

	-- set AuthToken when it gets it
	local function networkListener(event)
		print(event.response)
		local response = json.decode(event.response)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else

			if (response.auth_token) then
				coronaCloudController.authToken = response.auth_token
				if coronaCloudController.debugEnabled then
					print(coronaCloudController.debugTextPrefix .. "User Logged In!")
					print(coronaCloudController.debugTextPrefix .. "Auth Token: "..coronaCloudController.authToken)
				end
				Runtime:dispatchEvent({name="LoggedIn"})
				if delegate then
					delegate.facebookCallback()
				end
				return true
			else
				if coronaCloudController.debugEnabled then
					print(coronaCloudController.debugTextPrefix .. "Login Error: "..event.response)
				end
				Runtime:dispatchEvent({name="LoginError", errorMsg=response.errors[1]})
			end
		end
	end

	_postCC(path, params, networkListener)

	return true
end

-------------------------------------------------

function coronaCloudController.isLoggedIn()

	if (coronaCloudController.authToken == "" ) then
		if coronaCloudController.debugEnabled then
			print(coronaCloudController.debugTextPrefix .. "Corona Cloud: User not logged in!")
		end
		return false
	else
		if coronaCloudController.debugEnabled then
			print(coronaCloudController.debugTextPrefix .. "Corona Cloud: User is logged in!")
		end
		return true
	end
end

-------------------------------------------------

function coronaCloudController.getAuthToken()
	return coronaCloudController.authToken
end

-------------------------------------------------

function coronaCloudController.setAuthToken(authToken)
	coronaCloudController.authToken = authToken
end

-------------------------------------------------

function coronaCloudController.getMyProfile(delegate)
	local params = "auth_token="..coronaCloudController.authToken

	local path = "my_profile.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "User Profile: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="MyProfile", results=response})
			
			if delegate then
				delegate.updateCache("user", response)
			end
			
		end
	end

	_getCC(path, params, networkListener)
end


function coronaCloudController.updateMyProfile(userName,firstName,lastName,passWord,profilePicture,facebookID,facebookEnabled,facebookAccessToken,twitterEnabled,twitterEnabledToken)
	local params = "auth_token="..coronaCloudController.authToken
	
	if userName ~= nil then params = params.."&username="..userName end
	if firstName ~= nil then params = params.."&first_name="..firstName end
	if lastName ~= nil then params = params.."&last_name="..lastName end
	if passWord ~= nil then params = params.."&password="..passWord end
	if profilePicture ~= nil then params = params.."&profile_picture="..profilePicture end
	if facebookID ~= nil then params = params.."&facebook_id="..facebookID end
	if facebookEnabled ~= nil then params = params.."&facebook_enabled="..facebookEnabled end
	if facebookAccessToken ~= nil then params = params.."&facebook_access_token="..facebookAccessToken end
	if twitterEnabled ~= nil then params = params.."&twitter_enabled="..twitterEnabled end
	if twitterEnabledToken ~= nil then params = params.."&twitter_enabled_token="..twitterEnabledToken end
	
	local path = "my_profile.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "My Profile Updated: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="MyProfileUpdated", results=response})
		end
	end

	_putCC(path, params, networkListener)

end

-------------------------------------------------

function coronaCloudController.registerDevice(deviceToken)
	-- detect current device and populate platform
	local curDevice = system.getInfo("model")
	local platform

	if curDevice == "iPhone" or "iPad" then
		if coronaCloudController.debugEnabled then
			print(coronaCloudController.debugTextPrefix .. "Current Device is: "..curDevice)
		end
		platform = "iOS"
	else
		-- Not iOS so much be Android
		if coronaCloudController.debugEnabled then
			print(coronaCloudController.debugTextPrefix .. "Current Device is: "..curDevice)
		end
		platform = "Android"
	end

	local params = "auth_token="..coronaCloudController.authToken
	params = params.."&device_id="..deviceToken
	params = params.."&platform="..platform

	local path = "devices.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Device Registered: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="DeviceRegistered", results=response})
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.registerUser(firstName, lastName, username, email, password)
	local params = "auth_token="..coronaCloudController.authToken
	params = params.."&username="..username
	params = params.."&first_name="..firstName
	params = params.."&last_name="..lastName
	params = params.."&email="..email
	params = params.."&password="..password

	local path = "users.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "User Registered: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="UserRegistered", results=response})
		end
	end

	_postCC(path, params, networkListener)

end

-------------------------------------------------

function coronaCloudController.recoverPassword(email)
	local params = "email="..email

	local path = "users/forgot.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Password Recovery Initiated: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="PasswordRecovery", results=response})
		end
	end

	_postCC(path, params, networkListener)

end

-------------------------------------------------
-- Leaderboards
-------------------------------------------------

function coronaCloudController.getLeaderboards()
	local params = "auth_token="..coronaCloudController.authToken

	local path = "leaderboards.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Leaderboards"..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Leaderboards", type="AllLeaderboards", results=response})
		end
	end

	_getCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.getLeaderboardScores(leaderboard)
	local params = "auth_token="..coronaCloudController.authToken

	local path = "leaderboards/"..leaderboard.."/scores.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Leaderboard Details: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Leaderboards", type="GetScores",results=response})
		end
	end

	_getCC(path, params, networkListener)
end

-------------------------------------------------
function coronaCloudController.submitHighScore(leaderboard, score)
	local params = "auth_token="..coronaCloudController.authToken
	params = params.."&value="..score

	local path = "leaderboards/"..leaderboard.."/scores.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Leaderboard Details: "..event.response)
			end
			Runtime:dispatchEvent({name="Leaderboards", type="ScoreSubmitted"})
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------
-- Achievements
-------------------------------------------------

function coronaCloudController.getAllAchievements()
	local params = ""
	
	local path = "achievements.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Achievements: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Achievements", type="AllAchievements", results=response})
		end
	end

	_getCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.getStatusOfAchievement(achievementID)
	local params = "auth_token="..coronaCloudController.authToken

	local path = "achievements/"..achievementID..".json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Achievement: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Achievements", type="AchievementStatus", results=response})
		end
	end

	_getCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.getMyUnlockedAchievements()
	local params = "auth_token="..coronaCloudController.authToken

	local path = "achievements_user.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Achievement: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Achievements", type="UnlockedAchievements", results=response})
		end
	end

	_getCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.unlockAchievement(achievementID, progress)
	local params = "auth_token="..coronaCloudController.authToken
	if progress ~= nil then 
		params = param.."&progress="..progress
	end

	local path = "achievements/unlock/"..achievementID..".json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Achievement Unlocked: "..event.response)
			end
			Runtime:dispatchEvent({name="Achievements", type="AchievementUnlocked"})
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------
-- Analytics
-------------------------------------------------

function coronaCloudController.submitEvent(eventDetails)
	local params = "auth_token="..coronaCloudController.authToken
	params = params.."&event_type="..eventDetails.event_type
	params = params.."&message="..eventDetails.message
	params = params.."&name="..eventDetails.name

	local path = "analytic_events.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Analytics Event Submitted: "..event.response)
			end
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------
-- Chat
-------------------------------------------------

function coronaCloudController.createChatRoom(chatRoomName)
	local params = "auth_token="..coronaCloudController.authToken
	params = params.."&name="..chatRoomName

	local path = "chats.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Chat Room Created: "..event.response)
			end
		end
	end

	_postCC(path, params, networkListener)

end

-------------------------------------------------

function coronaCloudController.deleteChatRoom(chatroomID)
	local params = "auth_token="..coronaCloudController.authToken
	
	local path = "chats/"..chatroomID..".json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
			print(coronaCloudController.debugTextPrefix .. "Chat Room Deleted: "..event.response)
			end
		end
	end

	_deleteCC(path, params, networkListener)

end

-------------------------------------------------

function coronaCloudController.sendMessageToChatRoom(chatroomID,message)
	local params = "auth_token="..coronaCloudController.authToken
	params = params.."&content="..message

	local path = "chats/"..chatroomID.."/send_message.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Message Sent: "..event.response)
			end
		end
	end

	_postCC(path, params, networkListener)

end

-------------------------------------------------

function coronaCloudController.addUserToChatRoom(userID,chatroomID)
	local params = "auth_token="..coronaCloudController.authToken
	params = params.."&user_id="..userID

	local path = "chats/"..chatroomID.."/add_user.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "User Added to Chat Room: "..event.response)
			end
		end
	end

	_postCC(path, params, networkListener)

end

-------------------------------------------------

function coronaCloudController.removeUserFromChatRoom(userID,chatroomID)
	local params = "auth_token="..coronaCloudController.authToken
	params = params.."&user_id="..userID
	
	local path = "chats/"..chatroomID.."/remove_user.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "User Removed from Chat Room: "..event.response)
			end
		end
	end

	_deleteCC(path, params, networkListener)

end
-------------------------------------------------

--Returns all the chat room the user is in
function coronaCloudController.getChatRooms()
	local params = "auth_token="..coronaCloudController.authToken

	local path = "chats.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Chat Rooms: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Chat", results=response})
		end
	end

	_getCC(path, params, networkListener)

end

-------------------------------------------------

function coronaCloudController.getChatHistory(chatroomID)
	local params = "auth_token="..coronaCloudController.authToken

	local path = "chats/"..chatroomID.."/get_recent_chats.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Chat Room History: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Chat", results=response})
		end
	end

	_getCC(path, params, networkListener)
end

-------------------------------------------------
--Return what users are currently in a chat room
function coronaCloudController.getUsersInChatRoom(chatroomID)
	local params = "auth_token="..coronaCloudController.authToken

	local path = "chats/"..chatroomID.."/members.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Chat Room Members: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Chat", results=response})
		end
	end

	_getCC(path, params, networkListener)

end

-------------------------------------------------
-- Friends
-------------------------------------------------

function coronaCloudController.getFriends()
	local params = "auth_token="..coronaCloudController.authToken

	local path = "friends.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Friends: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Friends", type="Friends", results=response})
		end
	end

	_getCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.addFriend(friendID)
	local params = "auth_token="..coronaCloudController.authToken
	params = params.."&friend_id="..friendID

	local path = "friends.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Friend Added: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Friends", type="FriendAdded", results=response})
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.removeFriend(friendID)
	local params = "auth_token="..coronaCloudController.authToken
	params = params.."&user_id="..friendID

	local path = "friends.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Friend Deleted: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Friends", type="FriendDeleted", results=response})
		end
	end

	_deleteCC(path, params, networkListener)
end

-------------------------------------------------
-- News
-------------------------------------------------

function coronaCloudController.getNews()
	local params = "auth_token="..coronaCloudController.authToken

	local path = "news.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "News: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="News", type="News", results=response})
		end
	end

	_getCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.getUnreadNews()
	local params = "auth_token="..coronaCloudController.authToken

	local path = "news/unread.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "News (Unread): "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="News", type="UnreadNews", results=response})
		end
	end

	_getCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.getNewsArticle(articleID)
	local params = "auth_token="..coronaCloudController.authToken

	local path = "news/"..articleID..".json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "News Article: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="News", type="NewsArticle", results=response})
		end
	end

	_getCC(path, params, networkListener)
end
-------------------------------------------------
-- Multiplayer
-------------------------------------------------

function coronaCloudController.createMatch()
	local params = "auth_token="..coronaCloudController.authToken
	
	local path = "matches.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Match Created: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Multiplayer", type="MatchCreated", results=response})
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.createMatchAndStart()
	local params = "auth_token="..coronaCloudController.authToken
	
	local path = "matches.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Match Created and Started: "..event.response)
			end
			local response = json.decode(event.response)

			-- Start match
			coronaCloudController.startMatch(response._id)
			Runtime:dispatchEvent({name="Multiplayer", type="MatchCreated", results=response})
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.getMatches()
	
	local params = "auth_token="..coronaCloudController.authToken

	local path = "matches.json"

	-- dispatch matches event with list of matches
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Get Matches: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Multiplayer", type="Matches", results=response})
		end
	end

	_getCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.getMatchDetails(matchID)
	local params = "auth_token="..coronaCloudController.authToken

	local path = "matches/"..matchID..".json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Get Match Details: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Multiplayer", type="MatchDetails", results=response})
		end
	end

	_getCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.deleteMatch(matchID)
	local params = "auth_token="..coronaCloudController.authToken

	local path = "matches/"..matchID..".json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Match Deleted: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Multiplayer", type="MatchDeleted", results=response})
		end
	end

	_deleteCC(path, params, networkListener)

end

-------------------------------------------------

function coronaCloudController.resignMatch(matchID, userAlert)
	local params = "auth_token="..coronaCloudController.authToken

	if (userAlert ~= nil) then
		params = params.."&user_alert="..userAlert
	end 

	local path = "matches/"..matchID.."/resign.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Match Resigned: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Multiplayer", type="MatchResigned", results=response})
		end
	end

	_deleteCC(path, params, networkListener)

end

-------------------------------------------------

function coronaCloudController.addPlayerToMatch(userID, matchID, userAlert)
	local params = "auth_token="..coronaCloudController.authToken
	params = params.."&user_id="..userID

	if (userAlert ~= nil) then
		params = params.."&user_alert="..userAlert
	end 

	
	local path = "matches/"..matchID.."/add_player.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Player Added to Match: "..event.response)
			end
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.deletePlayer(matchID,playerID)
	local params = "auth_token="..coronaCloudController.authToken
	params = params.."&player_id="..playerID

	local path = "matches/"..matchID.."/remove_player.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Player Removed: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Multiplayer", type="PlayerDeleted", results=response})
		end
	end

	_deleteCC(path, params, networkListener)

end

-------------------------------------------------

function coronaCloudController.addPlayerToMatchGroup(userID, groupID, matchID)
	local params = "auth_token="..coronaCloudController.authToken
	params = params.."&user_id="..userID
	params = params.."&group_id="..groupID
	
	local path = "matches/"..matchID.."/add_player_to_group.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Player Added to Match Group: "..event.response)
			end
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.submitMove(moveContent, targetGroup, targetUser, matchID, userAlert)
	local params = "auth_token="..coronaCloudController.authToken
	
	-- if targetgroup specified then add parameter
	if (targetGroup ~= nil) then
		params = params.."&group_id="..targetGroup
	end
	
	-- if targetUser specified then add parameter
	if (targetGroup ~= nil) then
		params = params.."&target_user_id="..targetUser
	end

	-- if userAlert specified then add parameter
	if (userAlert ~= nil) then
		params = params.."&user_alert="..userAlert
	end

	-- Base64 encode moveContent
	moveContent = _b64enc(moveContent)

	params = params.."&content="..moveContent
	
	local path = "matches/"..matchID.."/move.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Move Submitted: "..event.response)
			end
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.getRecentMoves(matchID, limit)
	local params = "auth_token="..coronaCloudController.authToken

	local path = "matches/"..matchID.."/get_recent_moves.json"

	-- Force get all moves
	params = params.."&criteria=all"

	-- Check if limit provided, if so add param
	if (limit ~= nil) then
		params = params.."&move_count="..limit
	end

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Recent Match Moves: "..event.response)
			end
			local response = json.decode(event.response)

			-- Decode content - Convenient!
			-- TODO: Need to made it iterate through all moves,
			-- not just one.
			if (response[1] ~= nil) then
				if coronaCloudController.debugEnabled then
					print(coronaCloudController.debugTextPrefix .. "Decoding Content")
				end
				response[1].content = _b64dec(response[1].content)
			end

			Runtime:dispatchEvent({name="Multiplayer", type="RecentMoves", results=response})
		end
	end

	_getCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.startMatch(matchID)
	local params = "auth_token="..coronaCloudController.authToken
	
	local path = "matches/"..matchID.."/start.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Match Started: "..event.response)
			end
			Runtime:dispatchEvent({name="Multiplayer", type="MatchStarted"})
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.stopMatch(matchID)
	local params = "auth_token="..coronaCloudController.authToken
	
	local path = "matches/"..matchID.."/stop.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Match Stopped: "..event.response)
			end
			Runtime:dispatchEvent({name="Multiplayer", type="MatchStopped"})

		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.acceptChallenge(matchID, userAlert)
	local params = "auth_token="..coronaCloudController.authToken
	
	if (userAlert ~= nil) then
		params = params.."&user_alert="..userAlert
	end 


	local path = "matches/"..matchID.."/accept_request.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Challenge Accepted: "..event.response)
			end
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.declineChallenge(matchID)
	local params = "auth_token="..coronaCloudController.authToken

	if (userAlert ~= nil) then
		params = params.."&user_alert="..userAlert
	end 
	
	local path = "matches/"..matchID.."/reject_request.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Challenge Declined: "..event.response)
			end
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.createRandomChallenge(matchID, matchType, userAlert)
	local params = "auth_token="..coronaCloudController.authToken
	
	if matchType ~= nil then 
		params = params.."&match_type="..matchType
	end

	if (userAlert ~= nil) then
		params = params.."&user_alert="..userAlert
	end 

	local path = "matches/random_match_up.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Random Challenge Sent: "..event.response)
			end
			Runtime:dispatchEvent({name="Multiplayer", type="RandomChallenge", results=response})
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.nudgeUser(matchID, userAlert, payLoad)
	local params = "auth_token="..coronaCloudController.authToken
	
	if (userAlert ~= nil) then
		params = params.."&user_alert="..userAlert
	end 

	if (payLoad ~= nil) then
		params = params.."&payload="..payLoad
	end

	local path = "matches/"..matchID.."/nudge.json"

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Send a nudge to a user: "..event.response)
			end
		end
	end

	_postCC(path, params, networkListener)
end

-------------------------------------------------

function coronaCloudController.pollMP(playerID)
	local path = "https://" .. coronaCloudController.CC_URL .. "/receive.json"
	path = path.."?player_id="..playerID

	-- set currentUser when it gets it
	local  function networkListener(event)
		if (event.isError) then
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Network Error")
				print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
			return false
		else
			if coronaCloudController.debugEnabled then
				print(coronaCloudController.debugTextPrefix .. "Connecting to the Corona Cloud Server: "..event.response)
			end
			local response = json.decode(event.response)
			Runtime:dispatchEvent({name="Multiplayer", type="Receive", results=response})
		end
	end

	network.request(path, "GET", networkListener)
end

-------------------------------------------------

function coronaCloudController.findUser(keyword)

    local params = "keyword=" .. _urlencode(keyword)

    local path = "users/search.json"

    -- set currentUser when it gets it
    local  function networkListener(event)
        if (event.isError) then
			if coronaCloudController.debugEnabled then
            	print(coronaCloudController.debugTextPrefix .. "findUser Network Error")
            	print(coronaCloudController.debugTextPrefix .. "Error: "..event.response)
			end
            return false
        else
			if coronaCloudController.debugEnabled then
            	print(coronaCloudController.debugTextPrefix .. "Search Results: "..event.response)
			end
            local response = json.decode(event.response)
            Runtime:dispatchEvent({name="SearchResult", results=response})
        end
    end

    _getCC(path, params, networkListener)
end

return coronaCloudController
