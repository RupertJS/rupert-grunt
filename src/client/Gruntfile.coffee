Path = require 'path'
request = require('superagent')
fs = require 'fs'
Q = require 'q'

module.exports = (grunt, config)->
    flatten = (a, b)-> a.concat b
    prefix = (prefix)-> (str)->"#{prefix}#{str}"

    testFileOrdering = grunt.expandFileArg('src/client', '**/')

    grunt.Config =
        watch:
            client:
                files: [
                    'src/client/**/*.js'
                    'src/client/**/*.coffee'
                    'src/client/**/*.jade'
                    'src/client/**/*.styl'
                ]
                tasks: [
                    'client'
                ]
                options:
                    spawn: false
        copy:
            client:
                files: [
                    expand: true
                    cwd: 'src/client'
                    src: ['index.html', 'assets/**/*']
                    dest: 'build/client'
                ]

    # butt - Browser Under Test Tools
    butt = []
    unless process.env.DEBUG
        if process.env.BAMBOO
            butt = ['PhantomJS']
        else if process.env.TRAVIS
            butt = ['Firefox']
        else
            butt = ['Chrome']


    preprocessors =
        'src/client/**/*test.coffee': [ 'coffee' ]
        'src/client/**/*mock.coffee': [ 'coffee' ]
        'src/client/tools/**/*.coffee': [ 'coffee' ]

    if true and (not process.env.DEBUG or process.env.COVER)
        preprocessors['www/application.js'] = [ 'coverage' ]

    grunt.Config =
        karma:
            client:
                options:
                    browsers: butt
                    frameworks: [ 'mocha', 'sinon-chai' ]
                    reporters: [ 'spec', 'junit', 'coverage' ]
                    singleRun: true,
                    logLevel: 'INFO'
                    preprocessors: preprocessors
                    files: [
                        'www/vendors.js'
                        'www/templates.js'
                        'www/application.js'

                        'node_modules/rupert/node_modules/' +
                            'angular-builds/angular-mocks.js'
                        'node_modules/rupert-grunt/node_modules/' +
                            'mockasing/src/tools/*'

                        'src/client/**/*mock.coffee'

                        testFileOrdering
                    ].reduce(flatten, [])
                    junitReporter:
                        outputFile: 'build/reports/karma.xml'
                    coverageReporter:
                        type: 'lcov'
                        dir: 'build/reports/coverage/'

    grunt.registerTask 'writeClient', ->
        done = @async()
        options = @options
            dest: './www'
            files: [
                'index.html'
                'application.js'
                'application.js.map'
                'templates.js'
                'vendors.js'
                'vendors.css'
                'all.css'
                'screen.css'
                'print.css'
            ]
        options.dest = Path.resolve process.cwd(), options.dest
        getFile = (file)->
            defer = Q.defer()
            grunt.verbose.writeln "Starting request for #{file}..."
            request.get("#{process.env.URL}#{file}")
            .buffer()
            .end (err, res)->
                return defer.reject err if err
                return defer.reject res if res.status isnt 200
                grunt.file.write Path.join(options.dest, file), res.text
                defer.resolve()
            defer.promise

        copyFiles = ->
            [
                'fonts/ionicons.ttf'
                'fonts/ionicons.svg'
                'fonts/ionicons.eot'
                'fonts/ionicons.woff'
            ].forEach (font)->
                root = './node_modules/ng-stassets/node_modules/ionic/release/'
                grunt.file.copy root + font, './www/' + font

        writeFiles = ->
            pass = true
            process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0'
            grunt.verbose.writeln 'Stassets compiled all files!'
            promises = options.files.map getFile
            copyFiles()
            Q.all(promises)
            .catch (err)->
                grunt.debug.write err
                grunt.debug.writeln ''
                pass = false
            .then ->
                process.env.NODE_TLS_REJECT_UNAUTHORIZED = null
                done pass

        require(config.server)
        setTimeout writeFiles, 4000

    grunt.registerTask 'testClient',
        'Run karma tests against the client.',
        [
            'writeClient'
            'karma:client'
        ]

    grunt.registerTask 'client',
        'Prepare and test the client.',
        [
            'testClient'
        ]