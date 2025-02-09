# Decompiling Gameboy DMG roms

Status: Blocked 🔴

## Analysis: 

So it seems that dissembling a gameboy rom is slightly more difficult 
then expected. You can dissemble recognized opcodes and their respective 
data but the real problem comes from trying to distinguish code from data. 

Because there is no one spec'd way to make a gameboy rom, you have to try 
and distinguish between data (sprites, sounds etc.) and code. This is 
equivalent to the halting problem in many ways. 

One fair apporximation is using a tracing algorithm to follow the code lines from 
the entrypoint to other parts of the code. Parts of the code that cannot be traced 
back to the entrypoint are marked as likely data. 

This is only an approximation and in the end results in analysis segments of the 
rom that have no jmp instruction. However in practice there are lots of 
reasons why code would also have this behaviour. 

Another option is to have an emulator play the game through to it's end 
and track which parts of the code have been run. Cross referencing that 
with the original ROM will give you a better idea of the regions that are 
data. 

Lastly you could hand analyse the game logic of the ROM and this would in 
turn reveal to you where the data would be stored.

Much more work then expected tbh.

Maybe we can make the emulator such that it has hooks into it to emmit code lines.
