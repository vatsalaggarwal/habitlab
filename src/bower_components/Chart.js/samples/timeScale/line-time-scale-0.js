
		var timeFormat = 'MM/DD/YYYY HH:mm';

		function randomScalingFactor() {
			return Math.round(Math.random() * 100 * (Math.random() > 0.5 ? -1 : 1));
		}

		function randomColorFactor() {
			return Math.round(Math.random() * 255);
		}

		function randomColor(opacity) {
			return 'rgba(' + randomColorFactor() + ',' + randomColorFactor() + ',' + randomColorFactor() + ',' + (opacity || '.3') + ')';
		}

		function newDate(days) {
			return moment().add(days, 'd').toDate();
		}

		function newDateString(days) {
			return moment().add(days, 'd').format(timeFormat);
		}

		function newTimestamp(days) {
			return moment().add(days, 'd').unix();
		}

		var config = {
			type: 'line',
			data: {
				labels: [newDate(0), newDate(1), newDate(2), newDate(3), newDate(4), newDate(5), newDate(6)], // Date Objects
				datasets: [{
					label: "My First dataset",
					data: [randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor()],
					fill: false,
					borderDash: [5, 5],
				}, {
					label: "My Second dataset",
					data: [randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor(), randomScalingFactor()],
				}, {
					label: "Dataset with point data",
					data: [{
						x: newDateString(0),
						y: randomScalingFactor()
					}, {
						x: newDateString(5),
						y: randomScalingFactor()
					}, {
						x: newDateString(7),
						y: randomScalingFactor()
					}, {
						x: newDateString(15),
						y: randomScalingFactor()
					}],
					fill: false
				}]
			},
			options: {
				responsive: true,
                title:{
                    display:true,
                    text:"Chart.js Time Scale"
                },
				scales: {
					xAxes: [{
						type: "time",
						time: {
							format: timeFormat,
							// round: 'day'
							tooltipFormat: 'll HH:mm'
						},
						scaleLabel: {
							display: true,
							labelString: 'Date'
						}
					}, ],
					yAxes: [{
						scaleLabel: {
							display: true,
							labelString: 'value'
						}
					}]
				},
			}
		};

		$.each(config.data.datasets, function(i, dataset) {
			dataset.borderColor = randomColor(0.4);
			dataset.backgroundColor = randomColor(0.5);
			dataset.pointBorderColor = randomColor(0.7);
			dataset.pointBackgroundColor = randomColor(0.5);
			dataset.pointBorderWidth = 1;
		});

		window.onload = function() {
			var ctx = document.getElementById("canvas").getContext("2d");
			window.myLine = new Chart(ctx, config);

		};

		$('#randomizeData').click(function() {
			$.each(config.data.datasets, function(i, dataset) {
				$.each(dataset.data, function(j, dataObj) {
					if (typeof dataObj === 'object') {
						dataObj.y = randomScalingFactor();
					} else {
						dataset.data[j] = randomScalingFactor();
					}
				});
			});

			window.myLine.update();
		});

		$('#addDataset').click(function() {
			var newDataset = {
				label: 'Dataset ' + config.data.datasets.length,
				borderColor: randomColor(0.4),
				backgroundColor: randomColor(0.5),
				pointBorderColor: randomColor(0.7),
				pointBackgroundColor: randomColor(0.5),
				pointBorderWidth: 1,
				data: [],
			};

			for (var index = 0; index < config.data.labels.length; ++index) {
				newDataset.data.push(randomScalingFactor());
			}

			config.data.datasets.push(newDataset);
			window.myLine.update();
		});

		$('#addData').click(function() {
			if (config.data.datasets.length > 0) {
				config.data.labels.push(newDate(config.data.labels.length));

				for (var index = 0; index < config.data.datasets.length; ++index) {
					if (typeof config.data.datasets[index].data[0] === "object") {
						config.data.datasets[index].data.push({
							x: newDate(config.data.datasets[index].data.length),
							y: randomScalingFactor(),
						});
					} else {
						config.data.datasets[index].data.push(randomScalingFactor());
					}
				}

				window.myLine.update();
			}
		});

		$('#removeDataset').click(function() {
			config.data.datasets.splice(0, 1);
			window.myLine.update();
		});

		$('#removeData').click(function() {
			config.data.labels.splice(-1, 1); // remove the label first

			config.data.datasets.forEach(function(dataset, datasetIndex) {
				dataset.data.pop();
			});

			window.myLine.update();
		});
	