import React, {Component} from "react";
import PropTypes from 'prop-types';
import classnames from 'classnames';

import style from 'house/style.styl';

export default class House extends Component {
  static propTypes = {
    current: PropTypes.bool,
    house: PropTypes.object,
    setCurrent: PropTypes.func,
  };

  state = {
    sections: this.props.house.sections,
  }

  selectHouse = () => {
    this.props.setCurrent(this.props.house);
  }

  render() {
    const {current, house} = this.props;
    const {sections} = house;

    return (
      <div
        className={classnames(
          style.house__wrap,
          {[style.house__wrap_current]: current},
          {[style.house__wrap_disabled]: house.disabled}
        )}
        onClick={house.disabled ? null : this.selectHouse}
      >
        <p className={style.house__title}>{house.title}</p>
      </div>
    );
  }
};
