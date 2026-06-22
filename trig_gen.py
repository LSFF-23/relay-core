import math

OFFSET = 32768
BUFFER = 64
MASK = 0x8000

print("Started.")

with open("rom_cos.hex", "w") as c, open("rom_sin.hex", "w") as s:
    for i in range(BUFFER):
        cv = int(math.cos(2*math.pi*i/64)*OFFSET)
        sv = int(math.sin(2*math.pi*i/64)*OFFSET)
        if cv == OFFSET: cv = OFFSET-1
        if sv == OFFSET: sv = OFFSET-1
        mcv = MASK | -cv if cv < 0 else cv
        msv = MASK | -sv if sv < 0 else sv
        c.write(f"{mcv:04X}{'\n' if i != (BUFFER-1) else ''}")
        s.write(f"{msv:04X}{'\n' if i != (BUFFER-1) else ''}")

print("Done.")
