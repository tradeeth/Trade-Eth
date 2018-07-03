/* global $ */

function checker() { // eslint-disable-line
  const name = $('#name')[0].value.replace(/[^A-Za-z0-9_]/gi, '');
  const validNames = ['TradeETH'];
  if (validNames.map(x => x.toUpperCase()).indexOf(name.toUpperCase()) >= 0) {
    $('#result').html(`${name.toUpperCase()} is an official Trade ETH representative.`);
  } else {
    $('#result').html(`${name.toUpperCase()} is NOT OFFICIAL.`);
  }
}
