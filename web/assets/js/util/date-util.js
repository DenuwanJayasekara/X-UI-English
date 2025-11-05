const oneMinute = 1000 * 60; // Milliseconds in one minute
const oneHour = oneMinute * 60; // Milliseconds in one hour
const oneDay = oneHour * 24; // Milliseconds in one day
const oneWeek = oneDay * 7; // Milliseconds in one week
const oneMonth = oneDay * 30; // Milliseconds in one month

/**
 * Decrease by days
 *
 * @param days Number of days to decrease
 */
Date.prototype.minusDays = function (days) {
    return this.minusMillis(oneDay * days);
};

/**
 * Increase by days
 *
 * @param days Number of days to increase
 */
Date.prototype.plusDays = function (days) {
    return this.plusMillis(oneDay * days);
};

/**
 * Decrease by hours
 *
 * @param hours Number of hours to decrease
 */
Date.prototype.minusHours = function (hours) {
    return this.minusMillis(oneHour * hours);
};

/**
 * Increase by hours
 *
 * @param hours Number of hours to increase
 */
Date.prototype.plusHours = function (hours) {
    return this.plusMillis(oneHour * hours);
};

/**
 * Decrease by minutes
 *
 * @param minutes Number of minutes to decrease
 */
Date.prototype.minusMinutes = function (minutes) {
    return this.minusMillis(oneMinute * minutes);
};

/**
 * Increase by minutes
 *
 * @param minutes Number of minutes to increase
 */
Date.prototype.plusMinutes = function (minutes) {
    return this.plusMillis(oneMinute * minutes);
};

/**
 * Decrease by milliseconds
 *
 * @param millis Number of milliseconds to decrease
 */
Date.prototype.minusMillis = function(millis) {
    let time = this.getTime() - millis;
    let newDate = new Date();
    newDate.setTime(time);
    return newDate;
};

/**
 * Increase by milliseconds
 *
 * @param millis Number of milliseconds to increase
 */
Date.prototype.plusMillis = function(millis) {
    let time = this.getTime() + millis;
    let newDate = new Date();
    newDate.setTime(time);
    return newDate;
};

/**
 * Set time to 00:00:00.000 of the day
 */
Date.prototype.setMinTime = function () {
    this.setHours(0);
    this.setMinutes(0);
    this.setSeconds(0);
    this.setMilliseconds(0);
    return this;
};

/**
 * Set time to 23:59:59.999 of the day
 */
Date.prototype.setMaxTime = function () {
    this.setHours(23);
    this.setMinutes(59);
    this.setSeconds(59);
    this.setMilliseconds(999);
    return this;
};

/**
 * Format date
 */
Date.prototype.formatDate = function () {
    return this.getFullYear() + "-" + addZero(this.getMonth() + 1) + "-" + addZero(this.getDate());
};

/**
 * Format time
 */
Date.prototype.formatTime = function () {
    return addZero(this.getHours()) + ":" + addZero(this.getMinutes()) + ":" + addZero(this.getSeconds());
};

/**
 * Format date and time
 *
 * @param split Separator between date and time, default is a space
 */
Date.prototype.formatDateTime = function (split = ' ') {
    return this.formatDate() + split + this.formatTime();
};

class DateUtil {

    // Convert string to Date object
    static parseDate(str) {
        return new Date(str.replace(/-/g, '/'));
    }

    static formatMillis(millis) {
        return moment(millis).format('YYYY-M-D H:m:s')
    }

    static firstDayOfMonth() {
        const date = new Date();
        date.setDate(1);
        date.setMinTime();
        return date;
    }
}