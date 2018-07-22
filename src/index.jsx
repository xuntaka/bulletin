import React from 'react';
import ReactDOM from 'react-dom';
import App from 'app';

ReactDOM.render(
  <App/>,
  document.querySelector('#app')
);

if (module.hot) {
  module.hot.accept('./app', () => {render(App);});
}
