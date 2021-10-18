port module Main exposing (main)

import Browser
import Csv.Decode as CD
import Debug exposing (toString)
import Element
import Element.Border
import Element.Input
import Html exposing (Html)
import Http
import Json.Decode exposing (Decoder)
import Json.Decode.Pipeline
import Json.Encode
import Material.Icons as Icons
import Material.Icons.Types exposing (Coloring(..))


type Location
    = Unavailable
    | Unknown
    | Known Coords
    | Denied


type TruckType
    = RegularTruck
    | PushCart
    | UnknownTruck
    | UnexpectedTruck String


type alias Truck =
    { name : String
    , facilityType : TruckType
    , locationDescription : String
    , address : String
    , menu : List String
    , location : Coords
    , schedule : Maybe String
    }


type alias Model =
    { location : Location
    , trucks : Maybe (List Truck)
    }


type Msg
    = FromPort (Result Json.Decode.Error MsgFromPort)
    | GetLocation
    | GotTruckData (Result Http.Error (Result CD.Error (List Truck)))


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Coords =
    { latitude : Float
    , longitude : Float
    }


type GeoLocationError
    = PermissionDenied
    | PositionUnavailable
    | GeoLocationTimeOut
    | UnknownGeoLocationError


type MsgFromPort
    = GeoCoords (Result GeoLocationError Coords)


msgFromPort : Decoder MsgFromPort
msgFromPort =
    Json.Decode.oneOf [ Json.Decode.map Ok coords, Json.Decode.map Err geoLocationError ] |> Json.Decode.map GeoCoords


literal : Decoder m -> m -> n -> Decoder n
literal dec val conc =
    dec
        |> Json.Decode.andThen
            (\res ->
                if res == val then
                    Json.Decode.succeed conc

                else
                    Json.Decode.fail ("Expected literal " ++ toString val ++ " got " ++ toString res)
            )


coords : Decoder Coords
coords =
    Json.Decode.succeed (\_ -> \lat -> \lng -> Coords lat lng)
        |> Json.Decode.Pipeline.required "type" (literal Json.Decode.string "newPosition" ())
        |> Json.Decode.Pipeline.required "latitude" Json.Decode.float
        |> Json.Decode.Pipeline.required "longitude" Json.Decode.float


geoLocationError : Decoder GeoLocationError
geoLocationError =
    Json.Decode.succeed (\_ -> identity)
        |> Json.Decode.Pipeline.required "type" (literal Json.Decode.string "positionError" ())
        |> Json.Decode.Pipeline.required "reason"
            (Json.Decode.oneOf
                [ literal Json.Decode.string "denied" PermissionDenied
                , literal Json.Decode.string "unavailable" PositionUnavailable
                , literal Json.Decode.string "timeout" GeoLocationTimeOut
                , literal Json.Decode.string "unknown" UnknownGeoLocationError
                ]
            )


port sendMessage : Json.Encode.Value -> Cmd msg


port messageReceiver : (Json.Encode.Value -> msg) -> Sub msg


type alias Flags =
    { hasGeoLocation : Bool }


init : Flags -> ( Model, Cmd Msg )
init { hasGeoLocation } =
    ( { location =
            if hasGeoLocation then
                Unknown

            else
                Unavailable
      , trucks = Nothing
      }
    , Http.get
        { url = "https://data.sfgov.org/api/views/rqzj-sfat/rows.csv"
        , expect =
            CD.decodeCsv CD.FieldNamesFromFirstRow trucks
                |> Result.map
                |> Http.expectString
        }
        |> Cmd.map GotTruckData
    )


trucks : CD.Decoder Truck
trucks =
    CD.into (\name -> \fac -> \loc -> \addr -> \menu -> \lat -> \lng -> \sched -> Truck name fac loc addr menu { latitude = lat, longitude = lng } sched)
        |> CD.pipeline (CD.field "Applicant" CD.string)
        |> CD.pipeline
            (CD.field "FacilityType"
                (CD.string
                    |> CD.map
                        (\facility ->
                            case facility of
                                "Truck" ->
                                    RegularTruck

                                "Push Cart" ->
                                    PushCart

                                "" ->
                                    UnknownTruck

                                _ ->
                                    UnexpectedTruck facility
                        )
                )
            )
        |> CD.pipeline (CD.field "LocationDescription" CD.string)
        |> CD.pipeline (CD.field "Address" CD.string)
        |> CD.pipeline (CD.field "FoodItems" (CD.string |> CD.map (String.split ":" >> List.concatMap (String.split ";"))))
        |> CD.pipeline (CD.field "Latitude" CD.float)
        |> CD.pipeline (CD.field "Longitude" CD.float)
        |> CD.pipeline
            (CD.field "Schedule"
                (CD.string
                    |> CD.map
                        (\val ->
                            case val of
                                "" ->
                                    Nothing

                                _ ->
                                    Just val
                        )
                )
            )


intoLocation : Result GeoLocationError Coords -> Location
intoLocation res =
    case res of
        Ok known ->
            Known known

        Err PermissionDenied ->
            Denied

        Err PositionUnavailable ->
            Unavailable

        Err GeoLocationTimeOut ->
            Unknown

        Err UnknownGeoLocationError ->
            Unknown


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FromPort (Ok (GeoCoords location)) ->
            ( { model | location = intoLocation location }, Cmd.none )

        GetLocation ->
            ( model, sendMessage <| Json.Encode.object [ ( "type", Json.Encode.string "getGeoLocation" ) ] )

        GotTruckData (Ok (Ok trks)) ->
            ( { model | trucks = Just trks }, Cmd.none )

        _ ->
            ( model, Cmd.none )


view : Model -> Html Msg
view model =
    Element.layout [] <|
        case model.location of
            Unknown ->
                searchNearBy

            Known crds ->
                case model.trucks of
                    Nothing ->
                        Element.text "Waiting for trucks"

                    Just trks ->
                        viewTrucks crds <| List.take 5 <| List.sortBy (\{ location } -> distance location crds) <| trks

            Unavailable ->
                Element.text "Try this app on a device with GPS (like your mobile phone)"

            Denied ->
                Element.column [ Element.width Element.fill, Element.height Element.fill ]
                    [ Element.paragraph [] [ Element.text "Please allow access to your location. This app is pretty useless otherwise :)" ]
                    , searchNearBy
                    ]


distance : Coords -> Coords -> Float
distance a b =
    let
        dlat =
            a.latitude - b.latitude

        dlng =
            a.longitude - b.longitude
    in
    dlat * dlat + dlng * dlng


viewTrucks : Coords -> List Truck -> Element.Element Msg
viewTrucks startPosition =
    Element.column [ Element.width Element.fill, Element.height Element.fill, Element.spacing 10 ]
        << List.map (viewTruck startPosition)


coordsToString : Coords -> String
coordsToString { latitude, longitude } =
    toString latitude ++ "," ++ toString longitude


googleMapsPathUrl : Coords -> Coords -> String
googleMapsPathUrl from to =
    "https://www.google.com/maps/dir/" ++ coordsToString from ++ "/" ++ coordsToString to


viewTruck : Coords -> Truck -> Element.Element Msg
viewTruck startCoords truck =
    Element.row []
        [ Element.el [ Element.centerY ] <|
            Element.text <|
                truck.name
                    ++ " : "
                    ++ truck.address
                    ++ " ("
                    ++ truck.locationDescription
                    ++ ")"
        , Element.link [ Element.centerY ]
            { url = googleMapsPathUrl startCoords truck.location
            , label = Element.html <| Icons.directions 36 Inherit
            }
        ]


searchNearBy : Element.Element Msg
searchNearBy =
    Element.el [ Element.width Element.fill, Element.height Element.fill ] <|
        Element.Input.button
            [ Element.centerX
            , Element.centerY
            , Element.Border.width 1
            , Element.Border.rounded 10
            , Element.padding 10
            ]
            { onPress = Just GetLocation, label = Element.text "Search nearby" }


subscriptions : Model -> Sub Msg
subscriptions _ =
    messageReceiver (\value -> FromPort <| Json.Decode.decodeValue msgFromPort value)
