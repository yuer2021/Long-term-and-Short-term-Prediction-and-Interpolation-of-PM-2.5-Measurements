# Long-term-and-Short-term-Prediction-and-Interpolation-of-PM-2.5-Measurements
With the PM2.5 data collected from the static and mobile sensors in Foshan and Tianjin, China, the objective of this project is to build a model for accurate, robust, and comprehensive prediction of PM2.5 levels in short-term, long-term, and interpolation for air quality control and regulation.
The overview of the main approaches used in this project includes: 
(1) identify primary periods of PM 2.5 levels for static and mobile sensors
（2） Pre-processed data using seasonal decomposition and Gaussian kernel smoothing
（3）built a GPR model for PM2.5 prediction using Matern 52 kernel function for short-term and Exponential for interpolation
and long-term
（4）Built a Long Short-Term Memory (LSTM) model
The overview of the main approaches used in this project includes: 
Overall, the prediction results are generally consistent with the nearby training data for all the cases, which indicates a reasonably well prediction accuracy of the model. Additionally, the prediction results of the robustness testing indicate that the model achieves a good balance between prediction accuracy and model stability.
