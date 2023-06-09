//
//  MoviesCollectionViewController.swift
//  Project6
//
//  Created for MPCS 501030
//

import UIKit

let defaults = UserDefaults.standard

class MoviesCollectionViewController: UICollectionViewController, UISearchResultsUpdating {
    
    /// The collection view data source
    var dataSource: UICollectionViewDiffableDataSource<Int, Movie>!
    
    //
    // MARK: - Lifecycle
    //
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up a search controller to show in the `NavigationBar`
        // Note that we are not using the full `SearchResults` functionality, we
        // are really only using it to present a `UISearchBar`
        let srchCtr = UISearchController(searchResultsController: nil)
        srchCtr.searchBar.delegate = self
        srchCtr.searchBar.text = "Love"
        srchCtr.searchBar.showsCancelButton = true
        navigationItem.hidesSearchBarWhenScrolling = true
        navigationItem.searchController = srchCtr
        
        srchCtr.searchResultsUpdater = self
        
        let searchTerms = defaults.stringArray(forKey: "searchTerms") ?? []
        print("search terms: ",searchTerms)
        
        // Use the `MovieClient` to fetch a list of movies
        print("DEBUG ----> about to fetch movies")
        
        let url = "https://itunes.apple.com/search?country=US&media=movie&limit=200&term=love"
        
        MovieClient.fetchMovies(url: url) { [weak self] moviesData, error in
            guard let moviesData = moviesData, error == nil else {
                print(error ?? NSError())
                return
            }
            
            DataManager.sharedInstance.refreshMovieData(moviesData.results)
            /// Update the collection view based on the current state of the `data` property
            var snapshot = NSDiffableDataSourceSnapshot<Int, Movie>()
            snapshot.appendSections([0])
            snapshot.appendItems(DataManager.sharedInstance.movies)
            
            self?.dataSource.apply(snapshot)
        }
        
        
        // Create the layout for the collection view
        collectionView.collectionViewLayout = makeLayout()
        
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, state in
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell",
                                                          for: indexPath) as! MoviesCollectionViewCell
            cell.titleLabel.text = state.trackName
            cell.priceLabel.text = String(state.trackPrice ?? 0.0)
            cell.ratingLabel.text = state.contentAdvisoryRating
            
            // FIXME: Use the new iOS15 Asycn Image API and include a placeholder image
            cell.imageView.image = UIImage(systemName: "swift")
            MovieClient.getImage ( url: state.artworkUrl100 ?? "", completion: { (image, error) in
                guard let image = image, error == nil else {
                    print(error ?? "")
                    return
                }
                cell.imageView.image = image
                
                // to set the color of the tile and also to change the color of the text on the tile for readability
                
                let averageColor = image.averageColor
                cell.backgroundColor = averageColor
                
                var brightness: CGFloat = 0
                averageColor!.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
                let textColor: UIColor = brightness > 0.5 ? .black : .white
                cell.titleLabel.textColor = textColor
                cell.priceLabel.textColor = textColor
                cell.ratingLabel.textColor = textColor
            })
            
            return cell
        }
    
        /// Update the collection view based on the current state of the `data` property
        var snapshot = NSDiffableDataSourceSnapshot<Int, Movie>()
        snapshot.appendSections([0])
        snapshot.appendItems(DataManager.sharedInstance.movies)
        
        dataSource.apply(snapshot)
    }

    
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    

    
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    
}

//
// MARK: - Navigation
//

extension MoviesCollectionViewController {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // There are two segue possible from this view controller: the popover filter or the detail view controller
        if segue.identifier == "popover" {
            
            // sets a delegate
            let filters = segue.destination as? FiltersViewController
            filters!.delegate = self

            segue.destination.preferredContentSize = CGSize(width: 300, height: 200)
            
            if let presentationController = segue.destination.popoverPresentationController { // 1
                presentationController.delegate = self // 2
            }
            
        } else {
            guard let detailViewController = segue.destination as? DetailViewController,
                  let selectedRow = collectionView.indexPathsForSelectedItems?.first?.row else {
                return
            }
            
            detailViewController.movie = DataManager.sharedInstance.filteredMovies[selectedRow]
        }
    }
}

//
// MARK: - Protocol Extensions
//

extension MoviesCollectionViewController: UIPopoverPresentationControllerDelegate {
    
    /// Delegate method to enforce the correct popover style
    func adaptivePresentationStyle(for controller: UIPresentationController,
                                   traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

extension MoviesCollectionViewController: MoviesFilterDelegate {

    // FIXME: Update the collection view based on the popover filters (including the release date)
    /// Update the collection view based on the popover filter selections
    func changeFilter(price: Float, rating: String, flag: Int) {
        var filteredMovies = DataManager.sharedInstance.movies.filter { movie in
            let isBelowSelectedPriceLimit = movie.trackPrice ?? 0 < price
            let matchesSelectedRating = rating == "anyRating" || movie.contentAdvisoryRating?.lowercased() == rating.lowercased()
            
            return isBelowSelectedPriceLimit && matchesSelectedRating
        }
        
        // uses the flag as an indicator to sort the filteredMovies
        
        if flag == 1 {
            filteredMovies.sort {
                guard let date1 = $0.releaseDate, let date2 = $1.releaseDate else {
                    return false // if either releaseDate is nil, we can't compare them, so we return false
                }
                return date1 > date2 // sorts by descending order of release date
            }
        }
        
        DataManager.sharedInstance.update1(filteredMovies)
        
        /// Update the collection view based on the current state of the `data` property
        var snapshot = NSDiffableDataSourceSnapshot<Int, Movie>()
        snapshot.appendSections([0])
        snapshot.appendItems(DataManager.sharedInstance.filteredMovies)
        
        dataSource.apply(snapshot)
    }
}

extension MoviesCollectionViewController: UISearchBarDelegate {
    
    func updateSearchResults(for srchCtr: UISearchController) {
        guard let searchText = srchCtr.searchBar.text else {return}
        print(searchText)
    }

    func searchBarSearchButtonClicked(_ srchCtr: UISearchBar) {
        // FIXME: Search after enter
        print("Clicked")
        
        var senturl = "https://itunes.apple.com/search?country=US&media=movie&limit=200&term="
        senturl += srchCtr.text!
        srchCtr.text = srchCtr.text!
        
        // sends a URL with the searchterm to get a "list" of filtered movies
        
        MovieClient.fetchMovies(url: senturl) { [weak self] moviesData, error in
            guard let moviesData = moviesData, error == nil else {
                print(error ?? NSError())
                return
            }
            
            DataManager.sharedInstance.refreshMovieData(moviesData.results)
            /// Update the collection view based on the current state of the `data` property
            var snapshot = NSDiffableDataSourceSnapshot<Int, Movie>()
            snapshot.appendSections([0])
            snapshot.appendItems(DataManager.sharedInstance.movies)
            
            self?.dataSource.apply(snapshot)
        }
        
        guard let searchText = srchCtr.text else {return}
        var searchTerms = defaults.stringArray(forKey: "searchTerms") ?? []
        searchTerms.append(searchText)
        defaults.set(searchTerms, forKey: "searchTerms")
    }
}

//
// MARK: - Collection View Setup
//

private extension MoviesCollectionViewController {
    
    //FIXME: Update the layout as you see fit to make it look "good"
    func makeLayout() -> UICollectionViewCompositionalLayout {
        return UICollectionViewCompositionalLayout { (section: Int, environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: NSCollectionLayoutDimension.fractionalWidth(1.0), heightDimension: NSCollectionLayoutDimension.absolute(200)))
            item.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
            
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),  heightDimension: .absolute(200))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
            
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
            return section
        }
    }

}

extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
    }
}
