# World of Warcraft - Songflower Timer addon (SongflowerTimerKeeper)

### Foreword
The year is 2019, you're playing Classic WoW and buffing for Molten Core around late August. Getting the Songflower buff is a right pain, because you have to traverse all of Felwood, likely with pvp enabled, buffs ticking, and your parses in MC on the line. This was until a level 20 Orc Warlock named Snackles on the Herod-US server arrived to save the day, using none other than this addon (coded by myself).

A couple of months later and the addon swiftly got replaced, but the legacy of the Songflower Timer Keeper did not. Thanks to everyone who made keeping the time fun, even if it took hours of standing still.

### How does it work?
The functionality of the addon is quite simple it runs constantly based on 2 important, and 2 less important event listeners, in order of importance:
* COMBAT_LOG_EVENT_UNFILTERED
* CHAT_MSG_*
* ADDON_LOADED
* PLAYER_LOGOUT

#### COMBAT_LOG_EVENT_UNFILTERED
This is where we are able to keep track of the buff being applied. We constantly check if the events of SPELL_AURA_APPLIED (new buff is applied) or SPELL_AURA_REFRESH (buff is refreshed) happens, and if they are we can start the Songflower Timer.

#### CHAT_MSG_*
This handles the chat commands, we want feedback when people ask for the timer. Here we give people a set amount of commands:
* !sf                    - Returns time until the songflower will be available again.
* !sf timer/t [timezone] - Converts current time until songflower will be available again to a different timezone.
* !sf remind/r [timer]   - Reminds the user when there's [timer] left until the songflower will be available again.
* !sf countdown/cd       - Toggles the countdown, counting down when there's 30, 15, and 5-1 seconds left on the timer for next available Songflower.
* !sf send/s [name]      - Sends the current timer to [name].
* [...] timer?           - Returns time until the songflower will be available again. Backup in case people ask "What's the timer?".

Alt commands: !fp, !sft, !songflower

There are also a series of slash commands, by using /sfk or /sftk
* /sfk timer [next|last|clear] [timer] - Tries to regain a lost timer using the caching system or clears a timer.
* /sfk send [name]                     - Same as send above.
* /sfk cd (toggle/t)                   - Same as countdown above.
* /sfk remindlist                      - Shows the list of current users who wish to be reminded.
* /sfk duty                            - Informs players that you are currently (not) keeping timer.
* /sfk warning [warning/clear] [...]   - Allows for custom warnings after command usage.

#### ADDON_LOADED
An attempt at creating a caching system between users. If one person has the timer and a new user logs in, that user will attempt to request the timer. See more below.

#### PLAYER_LOGOUT
Same as above.

### Custom caching system
Slightly before the addon was retired, I attempted to code a custom caching system. This had two different payloads, GET and POST, with some handlers inside:
#### GET
* RETRIEVE [RTV] - Retrieves and updates information from other clients.
* CHECK [CHK]    - Checks information against own information from other clients.

#### POST
* SEND [SND]        - Sends information to other clients through whispers.
* - TIMER [TMR]     - Information about current timer.
* - REPORT [REP]    - Information about current report list.
* - COUNTDOWN [CDE] - Information about client's countdown status.
* ADD [ADD]         - Request to be added to the report list.
* REMOVE [RMV]      - Request to be removed from the report list.
