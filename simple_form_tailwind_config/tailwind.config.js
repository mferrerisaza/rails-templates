module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './config/initializers/simple_form_tailwind.rb',
    './app/javascript/**/*.js'
  ],
  plugins: [
    require('@tailwindcss/forms'),
  ]
}
