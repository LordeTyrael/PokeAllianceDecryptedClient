// Vertex Shader (RAIN + FOG)
attribute vec2 a_Vertex;
attribute vec2 a_TexCoord;

uniform mat3 u_ProjectionMatrix;
uniform mat3 u_TransformMatrix;
uniform mat3 u_TextureMatrix;

uniform vec2 u_WalkOffset;    // deslocamento do mapa
uniform highp float u_GlobalTime;   // tempo global

const vec2 rainDirection = vec2(0.3, 1.0);
const vec2 fogDirection  = vec2( 1.0,  0.2);
const float rainSpeed    = 1.0;  // ajuste conforme convier (unidades UV/sec)
const float fogSpeed     = 0.2;
const float rainZoom     = 0.6;  // “zoom” da textura de chuva
const float fogZoom      = 0.6;  // “zoom” da textura de névoa

varying vec2 v_TexCoord;     // base
varying vec2 v_RainCoord;    // chuva
varying vec2 v_FogCoord;     // névoa
varying vec2 v_LightCoord;   // relâmpago

void main()
{
    // posição na tela
    gl_Position = vec4(
        (u_ProjectionMatrix * u_TransformMatrix * vec3(a_Vertex, 1.0)).xy,
        1.0, 1.0
    );

    // UV base (textura do terreno)
    vec2 baseUV = (u_TextureMatrix * vec3(a_TexCoord, 1.0)).xy;
    v_TexCoord  = baseUV;
    v_LightCoord = baseUV;

    // UV para chuva: same as neve
    v_RainCoord = (
        baseUV
      + u_WalkOffset
      + rainDirection * u_GlobalTime * rainSpeed
    ) / rainZoom;

    // UV para névoa
    v_FogCoord  = (
        baseUV
      + u_WalkOffset
      + fogDirection  * u_GlobalTime * fogSpeed
    ) / fogZoom;
}
