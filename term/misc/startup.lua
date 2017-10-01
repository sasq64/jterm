
bindKey(DK_MIDDLE_MOUSE, paste);

bindKey(DK_F3, function()
    setTermScale(2)
    setShader([[
        float m = mod(gl_FragCoord.y, 2.0);
        gl_FragColor = texture2D(tex, uv) * m * (active / 4.0 + 0.75);
    ]])
end)

bindKey(DK_F2, function()
    setTermScale(1)
    setShader('gl_FragColor = texture2D(tex, uv) * (active / 4.0 + 0.75);')
end)

setFont("Monospace-16");
-- setFont("Menlo-16")
setBorder(12)

colors = {
    0x002b36,
    0xdc322f,
    0x859900,
    0xb58900,
    0x268bd2,
    0x6c71c4,
    0x2aa198,
    0x93a1a1,
    0x657b83,
    0xdc322f,
    0x859900,
    0xb58900,
    0x268bd2,
    0x6c71c4,
    0x2aa198,
    0xfdf6e3
}

tangoColors = {
    0x2e3436,
    0xcc0000,
    0x4e9a06,
    0xc4a000,
    0x3465a4,
    0x75507b,
    0x06989a,
    0xd3d7cf,
    0x555753,
    0xef2929,
    0x8ae234,
    0xfce94f,
    0x729fcf,
    0xad7fa8,
    0x34e2e2,
    0xeeeeec,
}

setPalette(colors)
