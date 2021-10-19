# lunch-walk
Pass by the food truck on your Lunch Walk. This is an implementation of the [Food Truck Challenge](https://github.com/timfpark/take-home-engineering-challenge).

## Current features

Uses your browser's [geolocation](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation_API) to find the 5 nearest (straight-line distance) food trucks to you and provides links with directions to each of them.

## Dev

At the moment, the project is a Single Page App (SPA) written mainly in [Elm](https://elm-lang.org) and deployed using [Netlify](https://www.netlify.com).

### Run it locally

To deploy a development version of the app on your local machine (with live reload and running the amazing time travelling debugger), clone this directory, install `netlify-cli` (`npm install -g netlify-cli`) and then run `netlify dev` in the root directory.

### Deploy it to Netlify

You can deploy your own copy of this application to Netlify by clicking the button below.

<a href="https://app.netlify.com/start/deploy?repository=https://github.com/Victor-Savu/lunch-walk"><img src="https://www.netlify.com/img/deploy/button.svg" alt="Deploy to Netlify"></a>


### Technologies

#### [Elm](https://elm-lang.org)
Most of the functionality is written in the Elm programming language. The layout uses the popular [`elm-ui`](https://package.elm-lang.org/packages/mdgriffith/elm-ui/latest/) package.

#### [Netlify](https://www.netlify.com)
Netlify is a powerful one-stop-shop for web development. This package deploys automatically on Netlify.

#### [npm](https://npmjs.com)
The `package.json` and `package-lock.json` files are only used to bootstrap the Elm toolchain.  
While Elm is a compiled language that has its own dependency ecosystem (see `elm.json`), it is not a native language on Netlify. Luckily, the Elm compiler (and a helpful live-reload server named `elm-live`) are available as `npm` dependencies, which Netlify picks up from the `package.json` file.
That's about all we need to know about `npm` for this project.

#### [GitHub](https://github.com)
The most popular source controll management tool on the most popular source code hosting website. __Check out the projects section on this repository's GitHub page__ to see what features are considered and how development is going. Building software is a social activity after all, so please drop by!
