
        var randomScalingFactor = function() {
            return (Math.random() > 0.5 ? 1.0 : -1.0) * Math.round(Math.random() * 100);
        };
        var randomColorFactor = function() {
            return Math.round(Math.random() * 255);
        };

        var barChartData = {
            labels: ["January", "February", "March", "April", "May", "June", "July"],
            datasets: [{
                type: 'bar',
                label: 'Dataset 1',
                backgroundColor: "rgba(151,187,205,0.5)",
                data: [randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor()],
                borderColor: 'white',
                borderWidth: 2
            }, {
                type: 'line',
                label: 'Dataset 2',
                backgroundColor: "rgba(151,187,205,0.5)",
                data: [randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor()],
                borderColor: 'white',
                borderWidth: 2
            }, {
                type: 'bar',
                label: 'Dataset 3',
                backgroundColor: "rgba(220,220,220,0.5)",
                data: [randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor()]
            }, ]

        };
        window.onload = function() {
            var ctx = document.getElementById("canvas").getContext("2d");
            window.myBar = new Chart(ctx, {
                type: 'bar',
                data: barChartData,
                options: {
                    responsive: true,
                    title: {
                        display: true,
                        text: 'Chart.js Combo Bar Line Chart'
                    },
                    animation: {
                        onComplete: function () {
                            var chartInstance = this.chart;
                            var ctx = chartInstance.ctx;
                            ctx.textAlign = "center";

                            Chart.helpers.each(this.data.datasets.forEach(function (dataset, i) {
                                var meta = chartInstance.controller.getDatasetMeta(i);
                                Chart.helpers.each(meta.data.forEach(function (bar, index) {
                                    ctx.fillText(dataset.data[index], bar._model.x, bar._model.y - 10);
                                }),this)
                            }),this);
                        }
                    }
                }
            });
        };

        $('#randomizeData').click(function() {
            $.each(barChartData.datasets, function(i, dataset) {
                dataset.backgroundColor = 'rgba(' + randomColorFactor() + ',' + randomColorFactor() + ',' + randomColorFactor() + ',.7)';
                dataset.data = [randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor()];

            });
            window.myBar.update();
        });
    