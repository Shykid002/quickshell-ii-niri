import qs.services
import qs.modules.common
import qs.modules.common.widgets

import QtQuick
import QtQuick.Layouts
import qs.modules.bar

StyledPopup {
    id: root

    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        implicitWidth: Math.max(header.implicitWidth, gridLayout.implicitWidth, forecastRow.implicitWidth)
        spacing: 8

        // Header
        ColumnLayout {
            id: header
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                MaterialSymbol {
                    fill: 0
                    font.weight: Font.Medium
                    text: "location_on"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    text: Weather.data.city
                    font {
                        weight: Font.Medium
                        pixelSize: Appearance.font.pixelSize.normal
                    }
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
            StyledText {
                id: temp
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
                text: Weather.data.temp + " • " + Translation.tr("Feels like %1").arg(Weather.data.tempFeelsLike)
            }
        }

        // Metrics grid
        GridLayout {
            id: gridLayout
            columns: 2
            rowSpacing: 5
            columnSpacing: 5
            uniformCellWidths: true

            WeatherCard {
                title: Translation.tr("UV Index")
                symbol: "wb_sunny"
                value: Weather.data.uv
            }
            WeatherCard {
                title: Translation.tr("Wind")
                symbol: "air"
                value: `(${Weather.data.windDir}) ${Weather.data.wind}`
            }
            WeatherCard {
                title: Translation.tr("Precipitation")
                symbol: "rainy_light"
                value: Weather.data.precip
            }
            WeatherCard {
                title: Translation.tr("Humidity")
                symbol: "humidity_low"
                value: Weather.data.humidity
            }
            WeatherCard {
                title: Translation.tr("Visibility")
                symbol: "visibility"
                value: Weather.data.visib
            }
            WeatherCard {
                title: Translation.tr("Pressure")
                symbol: "readiness_score"
                value: Weather.data.press
            }
            WeatherCard {
                title: Translation.tr("Sunrise")
                symbol: "wb_twilight"
                value: Weather.data.sunrise
            }
            WeatherCard {
                title: Translation.tr("Sunset")
                symbol: "bedtime"
                value: Weather.data.sunset
            }
        }
        
        // Forecast section
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.colors.colLayer1
            visible: Weather.forecast.length > 0
        }
        
        RowLayout {
            id: forecastRow
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            visible: Weather.forecast.length > 0
            
            Repeater {
                model: Weather.forecast
                
                ColumnLayout {
                    spacing: 4
                    
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            const d = new Date(modelData.date + "T12:00:00");
                            const days = [Translation.tr("Sun"), Translation.tr("Mon"), Translation.tr("Tue"), 
                                         Translation.tr("Wed"), Translation.tr("Thu"), Translation.tr("Fri"), Translation.tr("Sat")];
                            return days[d.getDay()];
                        }
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: Icons.getWeatherIcon(modelData.wCode, false)
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer1
                    }
                    
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.tempMax
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                    }
                    
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.tempMin
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                    
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 2
                        visible: modelData.chanceOfRain > 0
                        
                        MaterialSymbol {
                            text: "water_drop"
                            iconSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: modelData.chanceOfRain + "%"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }
        }
    }
}
