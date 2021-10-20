use aws_lambda_events::event::apigw::{ApiGatewayProxyRequest, ApiGatewayProxyResponse};
use aws_lambda_events::encodings::Body;
use http::header::HeaderMap;
use lambda_runtime::{handler_fn, Context, Error};
use log::LevelFilter;
use simple_logger::SimpleLogger;
use reqwest;
use csv;

#[tokio::main]
async fn main() -> Result<(), Error> {
    SimpleLogger::new().with_level(LevelFilter::Info).init().unwrap();

    let func = handler_fn(my_handler);
    lambda_runtime::run(func).await?;
    Ok(())
}

fn select(from: &csv::StringRecord) -> csv::StringRecord {
    csv::StringRecord::from(
        Vec::from([1, 2, 4, 5, 10, 11, 14, 15, 17].map(|idx| &from[idx]))
    )
}

pub(crate) async fn my_handler(_: ApiGatewayProxyRequest, _: Context) -> Result<ApiGatewayProxyResponse, Error> {
    let res = reqwest::Client::new().get("https://data.sfgov.org/api/views/rqzj-sfat/rows.csv").send().await?.error_for_status()?;
    
    let text = res.text().await?;
    let mut rdr = csv::Reader::from_reader(text.as_bytes());
    let mut raw_record = csv::StringRecord::new();
    let headers = rdr.headers()?.clone();
    let mut wtr = csv::Writer::from_writer(vec![]);
    wtr.write_record(&select(&headers))?;

    while rdr.read_record(&mut raw_record)? {
        wtr.write_record(&select(&raw_record))?;
    }
    
    let resp = ApiGatewayProxyResponse {
        status_code: 200,
        headers: HeaderMap::new(),
        multi_value_headers: HeaderMap::new(),
        body: Some(Body::Text(String::from_utf8(wtr.into_inner()?)?)),
        is_base64_encoded: Some(false),
    };

    Ok(resp)
}