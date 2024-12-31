-- @noindex

---@class Col
Color = {}

Color.White = 0xffffffff
Color.Red = 0xff0000ff
Color.MaxAlpha = 255

---@param red integer
---@param gre integer
---@param blu integer
---@param alp integer?
---@return integer
function Color.CreateRGBA(red, gre, blu, alp)
    alp = alp or Color.MaxAlpha
    return ((red & 0xff) << 24) | ((gre & 0xff) << 16) | ((blu & 0xff) << 8) | (alp & 0xff)
end

function Color.GetColorTable(rgba)
    if not rgba then return { red = nil, green = nil, blue = nil, alpha = nil } end
    local red <const> = (rgba >> 24) & 0xff
    local green <const> = (rgba >> 16) & 0xff
    local blue <const> = (rgba >> 8) & 0xff
    local alpha <const> = rgba & 0xff

    return { red = red, green = green, blue = blue, alpha = alpha }
end