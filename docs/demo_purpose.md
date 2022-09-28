# Demo explanation

We are trying to implement here a simple REST API that receives an expense report id and returns a complete expense report with full user information and attachments (if there are any).

You probably are familiar with an expense report, but in case you haven't filled or seen it, here's one expense report sample I googled:

![Expense report sample](/docs/images/expense-report-sample.png)

Our expense report doesn't have exactly same information, because it's for demonstration purposes only.

## Input data

Our Logic App gets started when it receives a HTTP POST request that contains an expense report id expressed in json format:
```
{
	"id": "0e442f4f-5b37-49a2-b677-c1013c13e32f"
}
```

## Data sources

Here's an explanation (and a diagram) of all the data sources our Logic App will use and what kind of data these data sources have.

* The first data source is an external REST API, which will return the basic data structure (JSON formatted expense report).

* The second one is an Azure SQL Server database, which contains user id to user information mapping table.

* The third one is an Azure Blob Storage container, which has hierarchical folder structure enabled and contains attachment files (in this case, a photo of a receipt).

![Diagram](/docs/images/Azure_demo3.png)

## Operations

We want our Logic App to do these operations:
* retrieve a basic expense report (i.e. missing full user information and attachments) from the external REST API where the returned expense report id matches the id of the input payload (of the Logic App),
* based on `userId` of the expense report, read the matching first name and surname from the Azure SQL Server database table and add those to the final JSON data,
* read all the attachments matching expense report id, line number, and attachment number; generate [SAS URIs](https://docs.microsoft.com/en-us/azure/storage/common/storage-sas-overview) for those attachments, and add those SAS URIs to the final JSON data.

## Output

After those operations, output from our Logic App should look like this:


*Sample 1 (one attachment)*:
```
{
  "header": {
    "id": "0e442f4f-5b37-49a2-b677-c1013c13e32f",
    "description": "Protective shield for a mobile phone",
    "startDate": "2022-06-20",
    "endDate": "2022-06-20",
    "userId": "df03858b-0b02-454b-b847-d2dab7da967e",
    "firstName": "Marilyn",
    "surname": "Monroe"
  },
  "lines": [
    {
      "lineNumber": "1",
      "description": "Protective shield expense",
      "expenseType": "Mobile phone accessories",
      "startDate": "2022-06-20",
      "endDate": "2022-06-20",
      "amount": "69",
      "currency": "EUR",
      "attachments": [
        [
          {
            "attachmentNumber": "1",
            "description": "Receipt",
            "fileName": "receipt.jpg",
            "fileType": "image/jpeg",
            "uri": "https://sk101attachments.blob.core.windows.net/files/0e442f4f-5b37-49a2-b677-c1013c13e32f/1/1/receipt.jpg?sv=2018-03-28&sr=b&sig=8v%2FZV%2BwjhOv5J9q4%2F23ms1nrP4%2ByerLXJAsukAxJMIs%3D&se=2022-07-09T14%3A35%3A29Z&sp=r"
          }
        ]
      ]
    }
  ]
}
```

*Sample 2 (two lines/attachments)*:

```
{
  "header": {
    "id": "df6284b4-1240-45e5-a794-1cf289999632",
    "description": "Train trip Helsinki-Tampere-Helsinki",
    "startDate": "2022-05-21",
    "endDate": "2022-05-21",
    "userId": "63adbb5f-e6a1-4435-ba11-021e4928c9af",
    "firstName": "Sam",
    "surname": "Shepard"
  },
  "lines": [
    {
      "lineNumber": "1",
      "description": "Helsinki-Tampere",
      "expenseType": "Train travel",
      "startDate": "2022-05-21",
      "startTime": "10:00",
      "endDate": "2022-05-21",
      "endTime": "11:50",
      "amount": "49",
      "currency": "EUR",
      "attachments": [
        [
          {
            "attachmentNumber": "1",
            "description": "Train ticket as an image",
            "fileName": "train_ticket.jpg",
            "fileType": "image/jpeg",
            "uri": "https://sk101attachments.blob.core.windows.net/files/df6284b4-1240-45e5-a794-1cf289999632/1/1/train_ticket.jpg?sv=2018-03-28&sr=b&sig=e%2FonwnLcZKF0aTSR42S%2BDv69YZVCd8h8g350goN%2BYc8%3D&se=2022-07-09T14%3A27%3A20Z&sp=r"
          }
        ]
      ]
    },
    {
      "lineNumber": "2",
      "description": "Tampere-Helsinki",
      "expenseType": "Train travel",
      "startDate": "2022-05-21",
      "startTime": "16:00",
      "endDate": "2022-05-21",
      "endTime": "17:50",
      "amount": "49",
      "currency": "EUR",
      "attachments": [
        [
          {
            "attachmentNumber": "1",
            "description": "Train ticket as an image",
            "fileName": "train_ticket.jpg",
            "fileType": "image/jpeg",
            "uri": "https://sk101attachments.blob.core.windows.net/files/df6284b4-1240-45e5-a794-1cf289999632/2/1/train_ticket.jpg?sv=2018-03-28&sr=b&sig=zQ7SOF4RoJcKwIiCcvqmHjRrgIGgMdVqRbTx%2BCeDhVE%3D&se=2022-07-09T14%3A27%3A21Z&sp=r"
          }
        ]
      ]
    }
  ]
}
```