function [pred_pm2d5] = pm2d5_pred_model(train_data, test_data, problem_type)
% pm2d5 value prediction model function 
% input train_data (two tables, one for static and one for mobile)
% input train_data includes time, pm2d5, hmd, spd, tmp, lat and lon
% test_data: one table with six columns, time, hmd, spd, tmp , lat and lon
% problem_type: 1 for short term, 2 for long term, 3 for interpolation
% output: predicted pm2.5 value corresponding to the test data parameters.
% output: one vector

%convert the data to one big cell and separate the static and mobile data. 
train_data_table=[train_data.train_data_static;train_data.train_data_mobile];
train_data_cell={};
count=[];
num_static=[];
flag=0;
for i=2:size(train_data_table,1)
    if (train_data_table.time(i)< train_data_table.time(i-1))
       count=[count,i];
       if (i>size(train_data.train_data_static,1)&&(flag==0))
         num_static=length(count);
         flag=1;
       end
    end
end
count=[1,count,size(train_data_table,1)+1];

for i=2:length(count)
    train_data_cell{i-1}=train_data_table(count(i-1):count(i)-1,:);
end
%calculate the number of static and mobile sensor
num_static=num_static(1);
num_mobile=size(train_data_cell,2)-num_static;
data_combine=train_data_cell;%one cell with all data with tables for each sensor. 

%turning into minutely data
clearvars table
data_total_minute=cell(1,length(data_combine));
for i=1:length(data_combine)
    timearray=[];
    dataarray=[];
    time=data_combine{i}.time;
    %calculate the minute average data
    date = floor(datenum(time));
    unique_date = unique(date);
    date_ = datestr(time,'mm/dd/yyyy');
    date_ = gather(date_);
    [dayNumber,dayName] = weekday(datenum(date_,'mm/dd/yyyy'));
    hour_ = datestr(time,'HH');
    minute_=datestr(time,'MM');
    data = addvars(data_combine{i}, date_, dayName, hour_,minute_,dayNumber, 'Before','time',...
                    'NewVariableNames',{'date','dayName','hour','minute','dayNumber'});
    data_gb_datemin = grpstats(data,{'date','hour','minute'},{'mean'},'DataVars',{'hmd','spd','tmp','pm2d5','lat','lon'});
    
    time_minutely = unique(datetime(datenum(date_)+str2num(hour_)/24+str2num(minute_)/24/60,...
        'ConvertFrom','Datenum'));
    timearray=[timearray;time_minutely];
    dataarray=[dataarray;table2array(data_gb_datemin(:,5:10))];

data_total_minute{i}=[table(timearray),array2table(dataarray)];
data_total_minute{i}.Properties.VariableNames = ["time",'hmd','spd','tmp','pm2d5','lat','lon'];
end

%setting the period for different problem type
if (problem_type==1)|(problem_type==3)
    scale=0.5;
    scale_parameter=1;
else
    scale =1;
    scale_parameter=0.5;
end


%seasonal decomposition for static
data_cleaned_static=cell(1,num_static);
for i=1:num_static %only static
    T=60*24*scale;
    sw25=[1/(2*T);repmat(1/T,T-1,1);1/(2*T)];
    trend=conv(data_total_minute{i}.pm2d5,sw25,'same');
    %padding the trend
    trend_padded=[repmat(trend(T/2+1),T/2,1);trend(T/2+1:end-T/2);repmat(trend(end-T/2),T/2,1)];

    T1=length(data_total_minute{i}.pm2d5);
    sidx=cell(T,1);
    for ii=1:T
        sidx{ii,1}=ii:T:T1;
    end
    
    detrend_data=data_total_minute{i}.pm2d5-trend_padded;%detrend
    seasonal=cellfun(@(x) mean(detrend_data(x)),sidx); %generate seasonal trend
    nc=floor(T1/T);
    rm=mod(T1,T);
    seasonal=[repmat(seasonal,nc,1);seasonal(1:rm)];
    sBar=mean(seasonal);
    seasonal=seasonal-sBar;
    residual=data_total_minute{i}.pm2d5-trend_padded-seasonal;
    pm2d5_clean=trend_padded+seasonal;
    time=data_total_minute{i}.time;
    data_cleaned_static{i}=table(time,pm2d5_clean);
end

%seasonal trend for mobile
data_cleaned_mobile=cell(1,num_mobile);
for i=num_static+1:length(data_total_minute) %only mobile
    T=60*24*scale;%1 days
    sw25=[1/(2*T);repmat(1/T,T-1,1);1/(2*T)];
    trend=conv(data_total_minute{i}.pm2d5,sw25,'same');
    %padding the trend
    trend_padded=[repmat(trend(T/2+1),T/2,1);trend(T/2+1:end-T/2);repmat(trend(end-T/2),T/2,1)];

    T1=length(data_total_minute{i}.pm2d5);
    sidx=cell(T,1);
    for ii=1:T
        sidx{ii,1}=ii:T:T1;
    end
    
    detrend_data=data_total_minute{i}.pm2d5-trend_padded;%detrend
    seasonal=cellfun(@(x) mean(detrend_data(x)),sidx); %generate seasonal trend
    nc=floor(T1/T);
    rm=mod(T1,T);
    seasonal=[repmat(seasonal,nc,1);seasonal(1:rm)];
    sBar=mean(seasonal);
    seasonal=seasonal-sBar;
    residual=data_total_minute{i}.pm2d5-trend_padded-seasonal;
    pm2d5_clean=trend_padded+seasonal;
    time=data_total_minute{i}.time;
    data_cleaned_mobile{i-num_static}=table(time,pm2d5_clean);
end

%parameter cleaning for static sensor
data_total_pro=data_total_minute;
for i=1:num_static
    data_total_pro{i}.pm2d5=data_cleaned_static{i}.pm2d5_clean;
    data_total_pro{i}.hmd= smoothdata(data_total_pro{i}.hmd,'Gaussian',60*24*scale_parameter);
    data_total_pro{i}.spd= smoothdata(data_total_pro{i}.spd,'Gaussian',60*24*scale_parameter);
    data_total_pro{i}.tmp= smoothdata(data_total_pro{i}.tmp,'Gaussian',60*24*scale_parameter);
end

%parameter cleaning for mobile sensor

%setting the period for different problem type
if (problem_type==2)
    scale_2=0.5;
else
    scale_2 =1;
end


for i=1:num_mobile
    data_total_pro{i+num_static}.pm2d5=data_cleaned_mobile{i}.pm2d5_clean;
    data_total_pro{i+num_static}.hmd= smoothdata(data_total_pro{i+num_static}.hmd,'Gaussian',60*24*scale_parameter*scale_2);
    data_total_pro{i+num_static}.spd= smoothdata(data_total_pro{i+num_static}.spd,'Gaussian',60*24*scale_parameter*scale_2);
    data_total_pro{i+num_static}.tmp= smoothdata(data_total_pro{i+num_static}.tmp,'Gaussian',60*24*scale_parameter*scale_2);
end

%putting data into one matrix and sort the data
clearvars table
data_onematrix=table;
for i=1:length(data_total_pro)
    data_onematrix=[data_onematrix;data_total_pro{i}];
end
data_total_sorted= sortrows(data_onematrix);


%normalize the data, using range
timenum_train=datenum(data_total_sorted.time);
test_data.time=datenum(test_data.time);
data_total_norm_para=[timenum_train,data_total_sorted.hmd,data_total_sorted.spd,...
    data_total_sorted.tmp,data_total_sorted.lat,data_total_sorted.lon];
data_total_norm_para_withtest=[data_total_norm_para;table2array(test_data)];
data_total_norm_para_withtest=normalize(data_total_norm_para_withtest,'range');

%regression using Gaussian process
x=data_total_norm_para_withtest(1:end-size(test_data,1),:);
y = data_total_sorted.pm2d5;
gprMdl=fitrgp(x,y,'KernelFunction','exponential');
pred_pm2d5=predict(gprMdl,data_total_norm_para_withtest(end-size(test_data,1)+1:end,:));

end