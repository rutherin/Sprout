void calculateVertexDisplacement(inout vec3 viewSpace, in vec3 worldSpace, in vec2 lightmaps, in int matIDs) {
    #ifndef Vertex_Displacement
        return;
    #endif

    if (matIDs != 2 || lightmaps.y <= 0.1) return;

    bool  topVertex = gl_MultiTexCoord0.t < mc_midTexCoord.t;
    float ID = mc_Entity.x;
    float time = frameTimeCounter * 2.0;

    int waveType = 0;
    if (ID == TALLGRASS ||ID == ROSE || ID == WHEAT || ID == NETHER_WART || ID == CARROT ||
        ID == POTATO || ID == BROWN_SHROOM || ID == RED_SHROOM)
        waveType = 1;

    vec3 waves  = vec3(0.0);
         waves += sin((dot(worldSpace.xz, windDirection) + time) * 1.0) * vec3(windDirection.x, 0.0, windDirection.y) * 0.2;
         waves += sin((dot(worldSpace.xz, windDirection) + time) * 1.5) * vec3(windDirection.x, 0.0, windDirection.y) * 0.15;
         waves += sin((dot(worldSpace.xz, windDirection) + time) * 1.2) * vec3(windDirection.x, 0.0, windDirection.y) * 0.1;
         waves *= lightmaps.y;

    if (waveType == 1)
        viewSpace = viewSpace - mat3(gbufferModelView) * (waves * float(topVertex));
    else
        viewSpace = viewSpace - mat3(gbufferModelView) * (waves * 0.5) * 0.0;
}