module.exports = function () {
  const circular = {};
  circular.self = circular;
  console.log("fixture console", circular);
  return true;
};
