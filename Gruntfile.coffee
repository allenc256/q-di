module.exports = (grunt) ->
  grunt.initConfig({
    coffee: 
      compile:
        options:
          bare: true
        files:
          'lib/index.js': ['lib/*.coffee']
  })

  grunt.loadNpmTasks('grunt-contrib-coffee');

  grunt.registerTask('default', ['coffee']);
