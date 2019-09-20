#define vc_steps 20
#define vc_altitude 512.0
#define vc_thickness 384.0
#define vc_breakThreshold 0.05

uniform float eyeAltitude;

float vc_windTick   = frameTimeCounter*0.5;
const float invLog2 = 1.0/log(2.0);

vec3 planetCurvePosition(in vec3 x) {
    return vec3(x.x, length(x + vec3(0.0, atmosphere_planetRadius, 0.0))-atmosphere_planetRadius, x.z);
}

float getNoise3D(vec3 pos) {
    vec3 i          = floor(pos);
    vec3 f          = fract(pos);

    vec2 p1         = (i.xy+i.z*vec2(17.0)+f.xy);
    vec2 p2         = (i.xy+(i.z+1.0)*vec2(17.0))+f.xy;
    vec2 c1         = (p1+0.5)/noiseTextureResolution;
    vec2 c2         = (p2+0.5)/noiseTextureResolution;
    float r1        = texture(noisetex, c1).r;
    float r2        = texture(noisetex, c2).r;
    return mix(r1, r2, f.z);
}

float scatterIntegral(float transmittance, const float coeff) {
    float a   = -1.0/coeff;
    return transmittance * a - a;
}

float fbm(vec3 pos, vec3 offset, const float persistence, const float scale, const int octaves) {
    float n     = 1.0;
    float a     = 0.5;
    vec3 shift  = offset;
    float d     = a;

    for (int i = 0; i<octaves; ++i) {
        n   += getNoise3D(pos + shift*(1.0+(float(i)/octaves)*0.25))*a;
        pos *= scale;
        a   *= persistence;
        d   += a;
    }
    return n/d;
}

float vc_getCoverage(vec3 pos) {
    const float lowEdge     = vc_altitude;
    const float highEdge    = vc_altitude+vc_thickness;

    float lowErode  = 1.0-smoothstep(lowEdge, lowEdge+vc_thickness*0.15, pos.y);
    float highErode = smoothstep(lowEdge+vc_thickness*0.2, highEdge, pos.y);

    float lowFade   = smoothstep(lowEdge, lowEdge+vc_thickness*0.08, pos.y);
    float highFade  = 1.0-smoothstep(highEdge-vc_thickness*0.15, highEdge, pos.y);

    pos *= 0.003;

    vec3 wind       = vec3(-vc_windTick, 0.0, 0.0);

    float lcoverage = GetNoise(pos.xz+wind.xz);
        lcoverage   = smoothstep(0.2, 0.9, lcoverage);

    float shape     = fbm(pos, wind, 0.5, 2.0, 8);
        shape      -= 1.2;
        //shape      -= lcoverage;
        shape      *= lowFade*highFade;
        shape      -= lowErode*0.5;
        shape      -= highErode*0.5;

    return max(shape*0.01, 0.0);
}

void vc_render(inout vec3 scenecolor, vec3 viewvec, vec3 upvec, vec3 camerapos, float vdotl, float dither) {
    vec3 wvec   = mat3(gbufferModelViewInverse)*viewvec;
    vec2 psphere = rsi((atmosphere_planetRadius+eyeAltitude)*upvec, viewvec, atmosphere_planetRadius);
    bool visible = !((eyeAltitude<vc_altitude && psphere.y>0.0) || (eyeAltitude>(vc_altitude+vc_thickness) && wvec.y>0.0));

    if (visible) {
        const float lowEdge     = vc_altitude;
        const float highEdge    = vc_altitude+vc_thickness;

        vec2 bsphere    = rsi(vec3(0.0, 1.0, 0.0)*atmosphere_planetRadius+eyeAltitude, wvec, atmosphere_planetRadius+lowEdge);
        vec2 tsphere    = rsi(vec3(0.0, 1.0, 0.0)*atmosphere_planetRadius+eyeAltitude, wvec, atmosphere_planetRadius+highEdge);

        float startdist = eyeAltitude>highEdge ? tsphere.x : bsphere.y;
        float enddist   = eyeAltitude>highEdge ? bsphere.x : tsphere.y;

        vec3 startpos   = wvec*startdist;
        vec3 endpos     = wvec*enddist;

        startpos    = planetCurvePosition(startpos);
        endpos      = planetCurvePosition(endpos);

        vec3 bstep      = (endpos-startpos)/vc_steps;
        const float blength = vc_thickness/vc_steps;
        float stepsCoeff = length(bstep)/blength;
            stepsCoeff  = 0.5+clamp(stepsCoeff-1.25, 0.0, 3.0)*0.4;
        int steps       = int(vc_steps*stepsCoeff);

        vec3 rstep  = (endpos-startpos)/steps;
        vec3 rpos   = rstep*dither+startpos+camerapos;

        float rlength = length(rstep);

        vec2 scatter    = vec2(0.0);
        float transmittance = 1.0;
        float fade      = 1.0;

        vec3 sunlight   = vec3(1.0, 1.0, 1.0)*1.0;
        vec3 skylight   = vec3(0.2, 0.4, 1.0)*0.2;

        float oDmult    = sqrt(steps/(rlength*1.73205080757));

        for (int i = 0; i<steps; ++i, rpos += rstep) {
            if (rpos.y<lowEdge || rpos.y>highEdge || transmittance<vc_breakThreshold) continue;
            float dist  = length(rpos-camerapos);
            float dfade = clamp((dist-500.0)/40000, 0.0, 1.0);
            if ((1.0-dfade)<0.01) continue;

            float coverage = vc_getCoverage(rpos);
            if (coverage <= 0.0) continue;

            float oD    = coverage*rlength;
            if (oD <= 0.0) continue;

            float stept = exp2(-oD*invLog2);

            fade   -= dfade*transmittance;

            //scatter here

            transmittance *= stept;
        }
        transmittance   = clamp((transmittance-vc_breakThreshold)/(1.0-vc_breakThreshold), 0.0, 1.0);

        vec3 color      = sunlight*scatter.x*PI + skylight*scatter.y/PI;

        scenecolor     *= transmittance;
        scenecolor     += sunlight*(1.0-transmittance)*0.5;
    }
}