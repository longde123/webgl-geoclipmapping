exports = class Grid
    @title = '1.13 Magnifification'
    @cameraPos = [0, 0.5, 0]
    @cameraPitch = 10

    constructor: (@app) ->
        @shaders = []

        for name in ['lerp', 'smoothstep', 'euclidian', 'classicBicubic']
            @shaders.push
                name: name
                shader: app.gf.shader([
                    fs.read('texfuns/rect.shader')
                    fs.read("texfuns/#{name}.shader")
                    fs.read('display.shader')
                ])

        for name in ['bicubicLinear', 'polynom6th', 'bicubicSmoothstep', 'bspline', 'bell', 'catmull-rom']
            @shaders.push
                name: name
                shader: app.gf.shader([
                    fs.read('texfuns/rect.shader')
                    fs.read("texfuns/#{name}.shader")
                    fs.read("texfuns/generalBicubic.shader")
                    fs.read('display.shader')
                ])

        @shader = app.gf.shaderProxy(@shaders[0].shader)
       
        pointers = [
            {name:'position', size:2}
            {name:'barycentric', size:3}
        ]
        uniforms = [
            {name:'uTerrain', type:'sampler', value:app.height}
            {name:'uAlbedo', type:'sampler', value:app.albedo}
        ]

        @patchState = app.gf.state
            cull: 'back'
            vertexbuffer:
                pointers: pointers
                vertices: @patch(app.gridSize)
            shader: @shader
            depthTest: true
            uniforms: uniforms
        
        @ringState = app.gf.state
            cull: 'back'
            vertexbuffer:
                pointers: pointers
                vertices: @ring(app.gridSize)
            shader: @shader
            depthTest: true
            uniforms: uniforms
        
        @textureScale = app.addRange label: 'Texture Scale', value: 0, min: -5, max: 5, step:0.1, convert: (value) -> Math.pow(2, value)
        @gridLevels = app.addRange label: 'Grid Levels', value: 3, min: 0, max: 16
        @shaderSelect = app.addSelect
            label: 'Interpolation'
            value: 0
            options: for shader, i in @shaders
                {name:shader.name, option:i}
            onValue: (value) =>
                @shader.shader = @shaders[parseInt(value, 10)].shader

    
    onGridSize: (size) ->
        @patchState.vertices @patch size
        @ringState.vertices @ring size

    ring: (size) ->
        size /= 2

        innerLow = -size+size/2
        innerHigh = size-size/2
        innerSize = innerHigh - innerLow

        size += 1
        
        v = vertices = new Float32Array (Math.pow(size*2, 2) - Math.pow(innerSize, 2))*3*5*2
        i = 0
        for x in [-size...size]
            l = x
            r = x+1
            xInner = x >= innerLow and x < innerHigh
            for z in [-size...size]
                f = z
                b = z+1
                zInner = z >= innerLow and z < innerHigh
                if xInner and zInner
                    continue

                v[i++]=r; v[i++]=b; v[i++]=0; v[i++]=0; v[i++]=1
                v[i++]=r; v[i++]=f; v[i++]=0; v[i++]=1; v[i++]=0
                v[i++]=l; v[i++]=f; v[i++]=1; v[i++]=0; v[i++]=0
                
                v[i++]=l; v[i++]=b; v[i++]=0; v[i++]=0; v[i++]=1
                v[i++]=r; v[i++]=b; v[i++]=0; v[i++]=1; v[i++]=0
                v[i++]=l; v[i++]=f; v[i++]=1; v[i++]=0; v[i++]=0

        return vertices
        
    patch: (size) ->
        size /= 2
        size += 1

        v = vertices = new Float32Array(Math.pow(size*2, 2)*3*5*2)
        i = 0
        for x in [-size...size]
            l = x
            r = x+1
            for z in [-size...size]
                f = z
                b = z+1
                v[i++]=r; v[i++]=b; v[i++]=0; v[i++]=0; v[i++]=1
                v[i++]=r; v[i++]=f; v[i++]=0; v[i++]=1; v[i++]=0
                v[i++]=l; v[i++]=f; v[i++]=1; v[i++]=0; v[i++]=0
                
                v[i++]=l; v[i++]=b; v[i++]=0; v[i++]=0; v[i++]=1
                v[i++]=r; v[i++]=b; v[i++]=0; v[i++]=1; v[i++]=0
                v[i++]=l; v[i++]=f; v[i++]=1; v[i++]=0; v[i++]=0
        
        return vertices

    destroy: ->
        @shaderSelect.remove()
        for shader in @shaders
            shader.shader.destroy()
        @ringState.destroy()
        @patchState.destroy()
        @textureScale.remove()
        @gridLevels.remove()

    draw: ->
        @shader
            .uniformSetter(@app.camera)
            .float('terrainSize', @app.height.width)
            .float('startGridScale', @app.gridScale.value)
            .float('showGridLines', @app.gridLines)
            .float('gridSize', @app.gridSize)
            .float('textureScale', @textureScale.value)
            .float('morphFactor', 1)

        @patchState
            .float('gridScale', @app.gridScale.value)
            .draw()
       
        for level in [0...@gridLevels.value]
            scale = @app.gridScale.value * Math.pow(2, level+1)

            @ringState
                .float('gridScale', scale)
                .draw()
