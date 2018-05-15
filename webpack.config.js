const path = require('path');

module.exports = {
  entry: path.join(__dirname, "src/app.jsx"),
  output: {
    path: path.resolve(__dirname, "public/s/jsx"),
    filename: "app.js"
  },
  module: {
    rules: [
      {
        test: /\.(js|jsx)$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader"
        }
      },
      {
        use: [
          {
            loader: 'style-loader',
            options: {
              sourceMap: true
            }
          },
          {
            loader: 'css-loader',
            options: {
              sourceMap: true,
              modules: true,
              importLoaders: 1
            }
          },
          {
            loader: 'postcss-loader',
            options: {
              sourceMap: true
            }
          },
          {
            loader: 'stylus-loader',
            options: {
              sourceMap: true
            }
          }
        ],
        test: /\.(css|ss|styl)$/
      },
    ]
  },

  devServer: {
    contentBase: path.join(__dirname, "public/s/jsx"),
    compress: true,
    port: 8080,
    public: "bulletin.mvl.space"
  }
};
