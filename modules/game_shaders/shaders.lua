function init()
  -- add manually your shaders from /data/shaders

  -- map shaders
  g_shaders.createShader("map_default", "/shaders/map_default_vertex", "/shaders/map_default_fragment")
  g_shaders.createShader("map_grain", "/shaders/map_default_vertex", "/shaders/map_grain")

  g_shaders.createShader("map_rainbow", "/shaders/map_rainbow_vertex", "/shaders/map_rainbow_fragment")
  g_shaders.addTexture("map_rainbow", "/images/shaders/rainbow.png")

  g_shaders.createShader("map_grayscale", "/shaders/map_default_vertex", "/shaders/grayscale")
  g_shaders.createShader("map_bloom", "/shaders/map_default_vertex", "/shaders/bloom")
  g_shaders.createShader("map_sepia", "/shaders/map_default_vertex", "/shaders/sepia")
  g_shaders.createShader("map_underwater", "/shaders/map_default_vertex", "/shaders/underwater")
  g_shaders.createShader("map_snow", "/shaders/map_default_vertex", "/shaders/snow")
  g_shaders.createShader("map_red", "/shaders/map_default_vertex", "/shaders/map_red")

  g_shaders.createShader("map_new_snow", "/shaders/map_newsnow_vertex", "/shaders/new_snow")
  g_shaders.addTexture("map_new_snow", "/shaders/map/textures/snow.png")

  -- use modules.game_interface.gameMapPanel:setShader("map_rainbow") to set shader

  -- outfit shaders
  --g_shaders.createOutfitShader("outfit_default", "/shaders/outfit_default_vertex", "/shaders/outfit_default_fragment")
    g_shaders.createOutfitShader("pulse", "/shaders/outline_vertex", "/shaders/dan_fragment")
    g_shaders.createOutfitShader("blue", "/shaders/outline_vertex", "/shaders/outfit_blue")
    g_shaders.createOutfitShader("pink", "/shaders/outline_vertex", "/shaders/outfit_pink")
    g_shaders.createOutfitShader("gray", "/shaders/outline_vertex", "/shaders/outfit_gray")
    g_shaders.createOutfitShader("orange", "/shaders/outline_vertex", "/shaders/outfit_orange")
    g_shaders.createOutfitShader("purple", "/shaders/outline_vertex", "/shaders/outfit_purple")

    g_shaders.createOutfitShader("goldLegend", "/shaders/outline_vertex", "/shaders/pokealliance/outline/outline_legend")
    g_shaders.createOutfitShader("snow", "/shaders/outline_vertex", "/shaders/pokealliance/outline/outline_snow")
    g_shaders.createOutfitShader("snowPulse", "/shaders/outline_vertex", "/shaders/pokealliance/outline/outline_snow_pulse")
    g_shaders.createOutfitShader("extremeSnow", "/shaders/outline_vertex", "/shaders/pokealliance/outline/outline_extreme_snow")

    g_shaders.createOutfitShader("itemPremier", "/shaders/outline_vertex", "/shaders/pokealliance/outline/item_rainbow")
    g_shaders.createOutfitShader("itemCyanPulse", "/shaders/pokealliance/outline/item_cyanpulse", "/shaders/pokealliance/outline/inside_pulse_vertex")
    g_shaders.createOutfitShader("downtop", "/shaders/pokealliance/outline/item_outline_vertex", "/shaders/pokealliance/outline/item_outline_pulse_cyan")
    g_shaders.createOutfitShader("happiness", "/shaders/outfit_line_vertex", "/shaders/outfit_line_fragment")

    --g_shaders.createShader("map_rain", "/shaders/map/map_heavy_rain_lightning_vertex", "/shaders/map/map_heavy_rain_lightning_fragment")
    --g_shaders.addTexture("map_rain", "/shaders/map/textures/heavy_rain.png")

    --g_shaders.createShader("map_fog", "/shaders/map/map_heavy_rain_lightning_vertex", "/shaders/map/map_heavy_rain_lightning_fragment")
    --g_shaders.addTexture("map_fog", "/shaders/map/textures/heavy_fog.png")
    --g_shaders.addTexture("map_rain", "/shaders/map/textures/heavy_fog.png")
    --g_shaders.addTexture("map_rain", "/shaders/map/textures/lightning.png")
    --g_shaders.createShader("map_lightning", "/shaders/map/map_heavy_rain_lightning_vertex", "/shaders/map/map_heavy_rain_lightning_fragment")

  --g_shaders.addTexture("pulse", "/images/shaders/rainbow.png")

  --g_shaders.createOutfitShader("pulse", "/shaders/outfit_circle_vertex", "/shaders/outfit_circle_red")
  --g_shaders.createOutfitShader("pulse", "/shaders/outfit_line_vertex", "/shaders/outfit_outline_fragment")
  --g_shaders.addTexture("pulse", "/images/shaders/default.png")

  -- you can use creature:setOutfitShader("outfit_rainbow") to set shader

end

function terminate()
end
