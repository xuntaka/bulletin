import React, {Component} from 'react';
import PropTypes from 'prop-types';
import {hot} from 'react-hot-loader';
import classnames from 'classnames';

import style from 'style';

import House from 'house';

function range(start, end) {
    var foo = [];
    for (var i = start; i <= end; i++) {
        foo.push(i);
    }
    return foo;
}

const houses = [
  {
    disabled: true,
    number: 16,
    title: 'Лесная 16',
    sections: [
      range(  1,  39), //  1 14x3
      range( 40,  78), //  2 14x3
      range( 79, 122), //  3 12x4
      range(123, 174), //  4 14x4
      range(175, 207), //  5 12x3
      range(208, 240), //  6 12x4
      range(241, 278), //  7 14x4
      range(279, 311), //  8 12x4
      range(312, 344), //  9 12x3
      range(345, 396), // 10 14x4
      range(397, 440), // 11 12x4
      range(441, 479), // 12 14x3
      range(480, 518), // 13 14x3
    ],
  },
  {
    disabled: true,
    number: 17,
    title: 'Лесная 17',
    sections: [
      range(  1,  39), //  1 14x3
      range( 40,  78), //  2 14x3
      range( 79, 122), //  3 12x4
      range(123, 174), //  4 14x4
      range(175, 207), //  5 12x3
      range(208, 240), //  6 12x4
      range(241, 278), //  7 14x4
      range(279, 311), //  8 12x4
      range(312, 344), //  9 12x3
      range(345, 396), // 10 14x4
      range(397, 440), // 11 12x4
      range(441, 479), // 12 14x3
      range(480, 518), // 13 14x3
    ],
  },
  {
    disabled: true,
    number: 18,
    title: 'Лесная 18',
    sections: [
      range(  1,  39), //  1 14x3
      range( 40,  72), //  2 12x3
      range( 73, 105), //  3 12x3
      range(106, 157), //  4 14x4
    ],
  },
  {
    number: 3,
    title: 'Кленовая 3',
    sections: [
      range(  1,  24),
      range( 25,  42),
      range( 43,  72),
      range( 73, 102),
      range(103, 132),
      range(133, 155),
      range(156, 187),
      range(188, 211),
      range(212, 229),
      range(230, 247),
      range(248, 265),
    ],
  },
];

export default hot(module)(class App extends Component {
  state = {
    house: null,
    section: null,
    flats: {},
  }

  setHouse = (house) => {
    this.setState({
      house: house.number,
      section: null,
      flats: {},
    });
  }

  setSection = (section) => {
    const {flats, house} = this.state;

    // if (! flats[section]) {
    //   let selectedHouse = houses.filter(item => house === item.number)[0];
    //   selectedHouse.sections[section].map(item => flats[item] = 1);
    // }

    this.setState({
      flats: flats,
      section: section,
    });
  }

  toggleFlat = (flat) => {
    const {flats} = this.state;

    flats[flat] = flats[flat] ? 0 : 1;

    this.setState({
      flats: flats,
    });
  }

  render() {
    const {flats, house, section} = this.state;

    let selectedHouse = houses.filter(item => house === item.number)[0];
    let flatsList = Object.keys(flats).filter(fl => flats[fl] > 0);
    let url =`/pdf/?house=${house}&flats=`;
    url += flatsList.join(',');
    url += '&download';

    return (
      <div>
        <div className={style.row__wrap}>
          <div className={style.row__list}>
            {
              houses.map((H, i) => {
                return <House
                  key={i}
                  house={H}
                  current={house === H.number}
                  setCurrent={this.setHouse}
                />
              })
            }
          </div>
        </div>
        {house > 0 ?
        <div className={style.row__wrap}>
          <div className={style.row__title}>Секции</div>
          <div className={style.row__list_sections}>
          {
            selectedHouse.sections.map((S, i) => {
              return <div
                className={classnames(
                  style.section__wrap,
                  {[style.section__wrap_current]: section === i}
                )}
                key={i}
                onClick={this.setSection.bind(null, i)}
              >
                {i + 1}
              </div>;
            })
          }
          </div>
        </div>
        : null}
        {section !== null ?
        <div className={style.row__wrap}>
          <div className={style.row__title}>Квартиры</div>
          <div className={style.row__list_flats}>
          {
            selectedHouse.sections[section].map((F, i) => {
              return <div
                className={classnames(
                  style.flat__wrap,
                  {[style.flat__wrap_current]: flats[F]}
                )}
                key={i}
                onClick={this.toggleFlat.bind(null, F)}
              >
                {F}
              </div>;
            })
          }
          </div>
        </div>
        : null}
        {flatsList.length ?
          <a href={url}>Скачать</a>
        : null}
      </div>
    );

    // 
  }
});
