package Model;
import DbDriver.*;

/**
 * Write a description of class Nodes here.
 * 
 * @author (your name) 
 * @version (a version number or a date)
 */
public class Nodes extends BaseModel {
    public Nodes(App.Context c){
        super(c);
    }
    
    public String getTableName(){
        return "node";
    }
}
